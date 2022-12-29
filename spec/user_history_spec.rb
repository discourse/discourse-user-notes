# frozen_string_literal: true

require "rails_helper"

describe UserHistory do
  let(:user) { Fabricate(:user, suspended_till: 7.days.from_now) }
  let(:admin) { Fabricate(:admin) }

  describe "when a user suspension log is created" do
    context "when staff notes plugin is enabled" do
      before { SiteSetting.user_notes_enabled = true }

      it "should create staff note for suspension" do
        UserHistory.create!(
          action: UserHistory.actions[:suspend_user],
          target_user_id: user.id,
          acting_user_id: admin.id,
        )

        expect(PluginStore.get("user_notes", "notes:#{user.id}")).to be_present
      end

      it "should use system language" do
        freeze_time

        UserHistory.create!(
          action: UserHistory.actions[:suspend_user],
          target_user_id: user.id,
          acting_user_id: admin.id,
        )

        I18n.with_locale(:fr) do # Simulate request from french user
          UserHistory.create!(
            action: UserHistory.actions[:suspend_user],
            target_user_id: user.id,
            acting_user_id: admin.id,
          )
        end

        notes = PluginStore.get("user_notes", "notes:#{user.id}")
        expect(notes[0]["raw"]).to eq(notes[1]["raw"])
      end
    end
  end
end
