require 'rails_helper'

describe Report do
  describe 'staff notes report' do
    let(:report) { Report.find('staff_notes') }
    let(:user) { Fabricate(:user) }
    let(:mod) { Fabricate(:admin) }
    let(:first_topic) { Fabricate(:topic) }
    let(:second_topic) { Fabricate(:topic) }

    context "when there are no staff notes" do
      before do
        SiteSetting.staff_notes_enabled = true
      end

      it "should return a report with no data" do
        expect(report.data).to be_blank
      end
    end

    context "when there are staff notes" do
      before do
        SiteSetting.staff_notes_enabled = true
        UserWarning.create(topic_id: first_topic.id, user_id: user.id, created_by_id: mod.id)
        UserWarning.create(topic_id: second_topic.id, user_id: user.id, created_by_id: mod.id)
      end

      it "should return the most recent note for the user" do
        expect(report.data[0][:note]).to match(/#{second_topic.title}/)
      end

      it "should return the user URLs" do
        expect(report.data[0][:user_url]).to eq("/admin/users/#{user.id}/#{user.username_lower}")
        expect(report.data[0][:moderator_url]).to eq("/admin/users/-1/system")
      end
    end
  end
end
