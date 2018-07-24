# name: discourse-staff-notes
# about: Gives the ability for staff members to attach notes to users
# version: 0.0.2
# authors: Robin Ward
# url: https://github.com/discourse/discourse-staff-notes

enabled_site_setting :staff_notes_enabled

register_asset 'stylesheets/staff_notes.scss'

STAFF_NOTE_COUNT_FIELD = "staff_notes_count"

after_initialize do

  require_dependency 'user'

  module ::DiscourseStaffNotes
    class Engine < ::Rails::Engine
      engine_name "discourse_staff_notes"
      isolate_namespace DiscourseStaffNotes
    end

    def self.key_for(user_id)
      "notes:#{user_id}"
    end

    def self.notes_for(user_id)
      PluginStore.get('staff_notes', key_for(user_id)) || []
    end

    def self.add_note(user, raw, created_by, opts = nil)
      opts ||= {}

      notes = notes_for(user.id)
      record = {
        id: SecureRandom.hex(16),
        user_id: user.id,
        raw: raw,
        created_by: created_by,
        created_at: Time.now
      }.merge(opts)

      notes << record
      ::PluginStore.set("staff_notes", key_for(user.id), notes)

      user.custom_fields[STAFF_NOTE_COUNT_FIELD] = notes.size
      user.save_custom_fields

      record
    end

    def self.remove_note(user, note_id)
      notes = notes_for(user.id)
      notes.reject! { |n| n[:id] == note_id }

      if notes.size > 0
        ::PluginStore.set("staff_notes", key_for(user.id), notes)
      else
        ::PluginStore.remove("staff_notes", key_for(user.id))
      end
      user.custom_fields[STAFF_NOTE_COUNT_FIELD] = notes.size
      user.save_custom_fields
    end

  end

  require_dependency 'application_serializer'
  class ::StaffNoteSerializer < ApplicationSerializer
    attributes(
      :id,
      :user_id,
      :raw,
      :created_by,
      :created_at,
      :can_delete,
      :post_id,
      :post_url,
      :post_title
    )

    def id
      object[:id]
    end

    def user_id
      object[:user_id]
    end

    def raw
      object[:raw]
    end

    def created_by
      BasicUserSerializer.new(object[:created_by], scope: scope, root: false)
    end

    def created_at
      object[:created_at]
    end

    def can_delete
      scope.can_delete_staff_notes?
    end

    def post_id
      object[:post_id]
    end

    def post_url
      url = object[:post].try(:url)

      # In case the topic is deleted
      if url == "/404"
        url = "/t/#{object[:post].topic_id}/#{object[:post].post_number}"
      end

      "#{Discourse.base_uri}#{url}"
    end

    def post_title
      object[:post].try(:title)
    end

    def topic_id
      object[:topic_id]
    end
  end

  require_dependency 'application_controller'
  class DiscourseStaffNotes::StaffNotesController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_staff

    def index
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      notes = ::DiscourseStaffNotes.notes_for(params[:user_id])
      render json: {
        extras: { username: user.username },
        staff_notes: create_json(notes)
      }
    end

    def create
      user = User.where(id: params[:staff_note][:user_id]).first
      raise Discourse::NotFound if user.blank?
      extras = {}
      if post_id = params[:staff_note][:post_id]
        extras[:post_id] = post_id
      end

      staff_note = ::DiscourseStaffNotes.add_note(
        user,
        params[:staff_note][:raw],
        current_user.id,
        extras
      )

      render json: create_json(staff_note)
    end

    def destroy
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      raise Discourse::InvalidAccess.new unless guardian.can_delete_staff_notes?

      ::DiscourseStaffNotes.remove_note(user, params[:id])
      render json: success_json
    end

    protected

    def create_json(obj)
      # Avoid n+1
      if obj.is_a?(Array)
        users_by_id = {}
        posts_by_id = {}
        User.where(id: obj.map { |o| o[:created_by] }).each do |u|
          users_by_id[u.id] = u
        end
        Post.with_deleted.where(id: obj.map { |o| o[:post_id] }).each do |p|
          posts_by_id[p.id] = p
        end
        obj.each do |o|
          o[:created_by] = users_by_id[o[:created_by].to_i]
          o[:post] = posts_by_id[o[:post_id].to_i]
        end
      else
        obj[:created_by] = User.where(id: obj[:created_by]).first
        obj[:post] = Post.with_deleted.where(id: obj[:post_id]).first
      end

      serialize_data(obj, ::StaffNoteSerializer)
    end
  end

  whitelist_staff_user_custom_field(STAFF_NOTE_COUNT_FIELD)

  add_to_class(Guardian, :can_delete_staff_notes?) do
    (SiteSetting.staff_notes_moderators_delete? && user.staff?) || user.admin?
  end

  add_to_serializer(:admin_detailed_user, :staff_notes_count, false) do
    object.custom_fields && object.custom_fields['staff_notes_count'].to_i
  end

  DiscourseStaffNotes::Engine.routes.draw do
    get '/' => 'staff_notes#index'
    post '/' => 'staff_notes#create'
    delete '/:id' => 'staff_notes#destroy'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseStaffNotes::Engine, at: "/staff_notes"
  end

  add_model_callback(UserWarning, :after_commit, on: :create) do
    user = User.find_by_id(self.user_id)
    created_by_user = User.find_by_id(self.created_by_id)
    warning_topic = Topic.find_by_id(self.topic_id)
    raw_note = I18n.t("staff_notes.official_warning", username: created_by_user.username, warning_link: "[#{warning_topic.title}](#{warning_topic.url})")
    ::DiscourseStaffNotes.add_note(
      user,
      raw_note,
      Discourse::SYSTEM_USER_ID,
      topic_id: self.topic_id
    )
  end

  add_model_callback(UserHistory, :after_commit, on: :create) do
    return unless self.action == UserHistory.actions[:suspend_user]
    target_user = User.find_by_id(self.target_user_id)
    created_by_user = User.find_by_id(self.acting_user_id)
    raw_note = I18n.t("staff_notes.user_suspended", username: created_by_user.username, suspended_till: I18n.l(target_user.suspended_till, format: :date_only), reason: self.details)
    ::DiscourseStaffNotes.add_note(
      target_user,
      raw_note,
      Discourse::SYSTEM_USER_ID,
      post_id: self.post_id,
      topic_id: self.topic_id
    )
  end

  on(:user_silenced) do |details|
    raw_note = I18n.t(
      "staff_notes.user_silenced",
      username: details[:silenced_by]&.username || '',
      silenced_till: I18n.l(details[:silenced_till], format: :date_only),
      reason: details[:reason]
    )
    note_args = {}
    if post = Post.with_deleted.where(id: details[:post_id]).first
      note_args = { post_id: post.id, topic_id: post.topic_id }
    end

    ::DiscourseStaffNotes.add_note(
      details[:user],
      raw_note,
      Discourse::SYSTEM_USER_ID,
      note_args
    )
  end

  if Report.respond_to? :add_report
    Report.add_report('staff_notes') do |report|
      report.modes = [:table]

      report.data = []

      report.labels = [
        { type: :link, properties: ["username", "user_url"], title: I18n.t("reports.staff_notes.labels.user") },
        { type: :link, properties: ["moderator_username", "moderator_url"], title: I18n.t("reports.staff_notes.labels.moderator") },
        { type: :text, properties: ["note"], title: I18n.t("reports.staff_notes.labels.note") }
      ]

      sql = <<~SQL
      WITH notes AS (
      SELECT (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'user_id')::int AS user_id,
      (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'created_by')::int AS staff_id,
      u.username_lower AS staff_username,
      value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'raw' AS note,
      (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'created_at')::date AS created_at
      FROM plugin_store_rows
      JOIN users u
      ON u.id = (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'created_by')::int
      WHERE plugin_name = 'staff_notes'
      AND (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'created_at')::date >= '#{report.start_date}'
      AND (value::jsonb->(jsonb_array_length(value::jsonb) - 1)->>'created_at')::date <= '#{report.end_date}'
      )
      SELECT n.user_id,
      u.username_lower,
      n.staff_id,
      n.staff_username,
      n.created_at,
      n.note
      FROM notes n
      JOIN users u
      ON u.id = n.user_id
      ORDER BY n.created_at DESC
      SQL

      DB.query(sql).each do |row|
        data = {}
        data[:created_at] = row.created_at
        data[:user_id] = row.user_id
        data[:username] = row.username_lower
        data[:user_url] = "/admin/users/#{row.user_id}/#{row.username_lower}"
        data[:moderator_id] = row.staff_id
        data[:moderator_username] = row.staff_username
        data[:moderator_url] = "/admin/users/#{row.staff_id}/#{row.staff_username}"
        data[:note] = row.note
        report.data << data
      end
    end
  end
end
