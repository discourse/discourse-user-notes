# frozen_string_literal: true

# name: discourse-user-notes
# about: Gives the ability for staff members to attach notes to users
# version: 0.0.2
# authors: Robin Ward
# url: https://github.com/discourse/discourse-user-notes
# transpile_js: true

enabled_site_setting :user_notes_enabled

register_asset "stylesheets/user_notes.scss"

register_svg_icon "sticky-note" if respond_to?(:register_svg_icon)

COUNT_FIELD = "user_notes_count"

after_initialize do
  require_dependency "user"

  module ::DiscourseUserNotes
    class Engine < ::Rails::Engine
      engine_name "discourse_user_notes"
      isolate_namespace DiscourseUserNotes
    end

    def self.key_for(user_id)
      "notes:#{user_id}"
    end

    def self.notes_for(user_id)
      PluginStore.get("user_notes", key_for(user_id)) || []
    end

    def self.add_note(user, raw, created_by, opts = nil)
      opts ||= {}

      notes = notes_for(user.id)
      record = {
        id: SecureRandom.hex(16),
        user_id: user.id,
        raw: raw,
        created_by: created_by,
        created_at: Time.now,
      }.merge(opts)

      notes << record
      ::PluginStore.set("user_notes", key_for(user.id), notes)

      user.custom_fields[COUNT_FIELD] = notes.size
      user.save_custom_fields

      record
    end

    def self.remove_note(user, note_id)
      notes = notes_for(user.id)
      notes.reject! { |n| n[:id] == note_id }

      if notes.size > 0
        ::PluginStore.set("user_notes", key_for(user.id), notes)
      else
        ::PluginStore.remove("user_notes", key_for(user.id))
      end
      user.custom_fields[COUNT_FIELD] = notes.size
      user.save_custom_fields
    end
  end

  require_dependency "application_serializer"
  class ::UserNoteSerializer < ApplicationSerializer
    attributes(
      :id,
      :user_id,
      :raw,
      :created_by,
      :created_at,
      :can_delete,
      :post_id,
      :post_url,
      :post_title,
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
      scope.can_delete_user_notes?
    end

    def post_id
      object[:post_id]
    end

    def post_url
      url = object[:post].try(:url)

      # In case the topic is deleted
      url = "/t/#{object[:post].topic_id}/#{object[:post].post_number}" if url == "/404"

      "#{Discourse.base_path}#{url}"
    end

    def post_title
      object[:post].try(:title)
    end

    def topic_id
      object[:topic_id]
    end
  end

  require_dependency "application_controller"
  class DiscourseUserNotes::UserNotesController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :ensure_staff

    def index
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      notes = ::DiscourseUserNotes.notes_for(params[:user_id])
      render json: { extras: { username: user.username }, user_notes: create_json(notes.reverse) }
    end

    def create
      user = User.where(id: params[:user_note][:user_id]).first
      raise Discourse::NotFound if user.blank?
      extras = {}
      if post_id = params[:user_note][:post_id]
        extras[:post_id] = post_id
      end

      user_note =
        ::DiscourseUserNotes.add_note(user, params[:user_note][:raw], current_user.id, extras)

      render json: create_json(user_note)
    end

    def destroy
      user = User.where(id: params[:user_id]).first
      raise Discourse::NotFound if user.blank?

      raise Discourse::InvalidAccess.new unless guardian.can_delete_user_notes?

      ::DiscourseUserNotes.remove_note(user, params[:id])
      render json: success_json
    end

    protected

    def create_json(obj)
      # Avoid n+1
      if obj.is_a?(Array)
        users_by_id = {}
        posts_by_id = {}
        User.where(id: obj.map { |o| o[:created_by] }).each { |u| users_by_id[u.id] = u }
        Post.with_deleted.where(id: obj.map { |o| o[:post_id] }).each { |p| posts_by_id[p.id] = p }
        obj.each do |o|
          o[:created_by] = users_by_id[o[:created_by].to_i]
          o[:post] = posts_by_id[o[:post_id].to_i]
        end
      else
        obj[:created_by] = User.where(id: obj[:created_by]).first
        obj[:post] = Post.with_deleted.where(id: obj[:post_id]).first
      end

      serialize_data(obj, ::UserNoteSerializer)
    end
  end

  # TODO Drop after Discourse 2.6.0 release
  if respond_to?(:allow_staff_user_custom_field)
    allow_staff_user_custom_field(COUNT_FIELD)
  else
    whitelist_staff_user_custom_field(COUNT_FIELD)
  end

  add_to_class(Guardian, :can_delete_user_notes?) do
    (SiteSetting.user_notes_moderators_delete? && user.staff?) || user.admin?
  end

  add_to_serializer(:admin_detailed_user, :user_notes_count, false) do
    object.custom_fields && object.custom_fields["user_notes_count"].to_i
  end

  DiscourseUserNotes::Engine.routes.draw do
    get "/" => "user_notes#index"
    post "/" => "user_notes#create"
    delete "/:id" => "user_notes#destroy"
  end

  Discourse::Application.routes.append { mount ::DiscourseUserNotes::Engine, at: "/user_notes" }

  add_model_callback(UserWarning, :after_commit, on: :create) do
    user = User.find_by_id(self.user_id)
    created_by_user = User.find_by_id(self.created_by_id)
    warning_topic = Topic.find_by_id(self.topic_id)
    raw_note =
      I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "user_notes.official_warning",
          username: created_by_user.username,
          warning_link: "[#{warning_topic.title}](#{warning_topic.url})",
        )
      end
    ::DiscourseUserNotes.add_note(
      user,
      raw_note,
      Discourse::SYSTEM_USER_ID,
      topic_id: self.topic_id,
    )
  end

  add_model_callback(UserHistory, :after_commit, on: :create) do
    return unless self.action == UserHistory.actions[:suspend_user]
    target_user = User.find_by_id(self.target_user_id)
    created_by_user = User.find_by_id(self.acting_user_id)
    raw_note =
      I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "user_notes.user_suspended",
          username: created_by_user.username,
          suspended_till: I18n.l(target_user.suspended_till, format: :date_only),
          reason: self.details,
        )
      end
    ::DiscourseUserNotes.add_note(
      target_user,
      raw_note,
      Discourse::SYSTEM_USER_ID,
      post_id: self.post_id,
      topic_id: self.topic_id,
    )
  end

  on(:user_silenced) do |details|
    raw_note =
      I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "user_notes.user_silenced",
          username: details[:silenced_by]&.username || "",
          silenced_till: I18n.l(details[:silenced_till], format: :date_only),
          reason: details[:reason],
        )
      end
    note_args = {}
    if post = Post.with_deleted.where(id: details[:post_id]).first
      note_args = { post_id: post.id, topic_id: post.topic_id }
    end

    ::DiscourseUserNotes.add_note(details[:user], raw_note, Discourse::SYSTEM_USER_ID, note_args)
  end

  if respond_to? :add_report
    add_report("user_notes") do |report|
      report.modes = [:table]

      report.data = []

      report.labels = [
        {
          type: :user,
          properties: {
            username: :username,
            id: :user_id,
            avatar: :user_avatar_template,
          },
          title: I18n.t("reports.user_notes.labels.user"),
        },
        {
          type: :user,
          properties: {
            username: :moderator_username,
            id: :moderator_id,
            avatar: :moderator_avatar_template,
          },
          title: I18n.t("reports.user_notes.labels.moderator"),
        },
        { type: :text, property: :note, title: I18n.t("reports.user_notes.labels.note") },
      ]

      values = []
      values =
        PluginStoreRow
          .where(plugin_name: "user_notes")
          .where("value::json->0->>'created_at'>=?", report.start_date)
          .where("value::json->0->>'created_at'<=?", report.end_date)
          .pluck(:value)

      values.each do |value|
        notes = JSON.parse(value)
        notes.each do |note|
          data = {}
          created_at = Time.parse(note["created_at"])
          user = User.find_by(id: note["user_id"])
          moderator = User.find_by(id: note["created_by"])

          if user && moderator
            data[:created_at] = created_at
            data[:user_id] = user.id
            data[:username] = user.username_lower
            data[:user_avatar_template] = User.avatar_template(
              user.username_lower,
              user.uploaded_avatar_id,
            )
            data[:moderator_id] = moderator.id
            data[:moderator_username] = moderator.username_lower
            data[:moderator_avatar_template] = User.avatar_template(
              moderator.username_lower,
              moderator.uploaded_avatar_id,
            )
            data[:note] = note["raw"]

            report.data << data
          end
        end
      end
    end
  end
end
