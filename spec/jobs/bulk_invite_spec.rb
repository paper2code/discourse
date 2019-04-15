require 'rails_helper'

describe Jobs::BulkInvite do
  describe '#execute' do
    let(:user) { Fabricate(:user) }
    let!(:group1) { Fabricate(:group, name: 'group1') }
    let!(:group2) { Fabricate(:group, name: 'group2') }
    let!(:topic) { Fabricate(:topic, id: 999) }
    let(:email) { "test@discourse.org" }
    let(:csv_info) { [] }
    let(:basename) { "bulk_invite.csv" }
    let(:filename) { "#{Invite.base_directory}/#{basename}" }

    before do
      FileUtils.cp(
        "#{Rails.root}/spec/fixtures/csv/#{basename}",
        filename
      )
    end

    it 'raises an error when the filename is missing' do
      user = Fabricate(:user)

      expect { Jobs::BulkInvite.new.execute(current_user_id: user.id) }
        .to raise_error(Discourse::InvalidParameters, /filename/)
    end

    it 'raises an error when current_user_id is not valid' do
      user = Fabricate(:user)

      expect { Jobs::BulkInvite.new.execute(filename: filename) }
        .to raise_error(Discourse::InvalidParameters, /current_user_id/)
    end

    it 'creates the right invites' do
      described_class.new.execute(
        current_user_id: Fabricate(:admin).id,
        filename: basename,
      )

      invite = Invite.last

      expect(invite.email).to eq(email)
      expect(Invite.exists?(email: "test2@discourse.org")).to eq(true)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id, group2.id
      )

      expect(invite.topic_invites.pluck(:topic_id)).to contain_exactly(topic.id)
    end

    it 'does not create invited groups for automatic groups' do
      group2.update!(automatic: true)

      described_class.new.execute(
        current_user_id: Fabricate(:admin).id,
        filename: basename,
      )

      invite = Invite.last

      expect(invite.email).to eq(email)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id
      )
    end

    it 'does not create invited groups record if the user can not manage the group' do
      group1.add_owner(user)

      described_class.new.execute(
        current_user_id: user.id,
        filename: basename
      )

      invite = Invite.last

      expect(invite.email).to eq(email)

      expect(invite.invited_groups.pluck(:group_id)).to contain_exactly(
        group1.id
      )
    end
  end

end
