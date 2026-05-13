# spec/services/milestone_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/milestone_service'

RSpec.describe MilestoneService do
  before do
    # Mock DB and REDIS to prevent actual calls
    stub_const('DB', double('DB'))
    stub_const('REDIS', double('REDIS'))
  end
  
  describe '.check_milestone' do
    it 'returns milestone data for 5 views' do
      milestone = MilestoneService.check_milestone(5)
      
      expect(milestone).to be_a(Hash)
      expect(milestone[:badge]).to eq('getting_started')
      expect(milestone[:title]).to eq('🎉 First 5!')
    end
    
    it 'returns milestone data for 100 views' do
      milestone = MilestoneService.check_milestone(100)
      
      expect(milestone[:badge]).to eq('century_club')
      expect(milestone[:title]).to eq('💯 Century Club!')
    end
    
    it 'returns nil for non-milestone counts' do
      expect(MilestoneService.check_milestone(15)).to be_nil
      expect(MilestoneService.check_milestone(75)).to be_nil
      expect(MilestoneService.check_milestone(150)).to be_nil
    end
    
    it 'returns data for legendary 1000 milestone' do
      milestone = MilestoneService.check_milestone(1000)
      
      expect(milestone[:badge]).to eq('meme_god')
      expect(milestone[:title]).to eq('👹 MEME GOD!')
    end
  end
  
  describe '.get_progress' do
    context 'when below first milestone' do
      it 'shows progress to 5 views' do
        progress = MilestoneService.get_progress(3)
        
        expect(progress[:current_count]).to eq(3)
        expect(progress[:next_milestone]).to eq(5)
        expect(progress[:memes_until_next]).to eq(2)
        expect(progress[:progress_percent]).to eq(60)
      end
    end
    
    context 'when between milestones' do
      it 'shows progress from 10 to 25' do
        progress = MilestoneService.get_progress(15)
        
        expect(progress[:current_count]).to eq(15)
        expect(progress[:next_milestone]).to eq(25)
        expect(progress[:memes_until_next]).to eq(10)
        expect(progress[:progress_percent]).to eq(33)
      end
      
      it 'shows progress from 50 to 100' do
        progress = MilestoneService.get_progress(75)
        
        expect(progress[:current_count]).to eq(75)
        expect(progress[:next_milestone]).to eq(100)
        expect(progress[:memes_until_next]).to eq(25)
        expect(progress[:progress_percent]).to eq(50)
      end
    end
    
    context 'when at a milestone' do
      it 'shows progress to next milestone from 25' do
        progress = MilestoneService.get_progress(25)
        
        expect(progress[:current_count]).to eq(25)
        expect(progress[:next_milestone]).to eq(50)
        expect(progress[:memes_until_next]).to eq(25)
      end
    end
    
    context 'when past all milestones' do
      it 'shows legendary status for 1500 views' do
        progress = MilestoneService.get_progress(1500)
        
        expect(progress[:current_count]).to eq(1500)
        expect(progress[:next_milestone]).to be_nil
        expect(progress[:progress_percent]).to eq(100)
        expect(progress[:status]).to eq('legendary')
      end
    end
  end
  
  describe '.award_milestone' do
    let(:milestone_data) do
      {
        badge: 'explorer',
        title: '🌟 Meme Explorer!',
        message: "25 memes! You're a true explorer!"
      }
    end
    
    context 'with valid database' do
      it 'stores achievement in database' do
        allow(DB).to receive(:execute).with(
          /INSERT INTO user_achievements/,
          anything
        )
        
        allow(DB).to receive(:execute).with(
          /INSERT INTO user_xp_log/,
          anything
        )
        
        allow(DB).to receive(:execute).with(
          /UPDATE users SET total_xp/,
          anything
        )
        
        allow(REDIS).to receive(:lpush)
        allow(REDIS).to receive(:ltrim)
        allow(REDIS).to receive(:expire)
        
        result = MilestoneService.award_milestone(123, milestone_data)
        expect(result).to be true
      end
      
      it 'awards correct XP amount' do
        xp_log_call = nil
        allow(DB).to receive(:execute) do |sql, params|
          xp_log_call = params if sql.include?('user_xp_log')
        end
        
        allow(REDIS).to receive(:lpush)
        allow(REDIS).to receive(:ltrim)
        allow(REDIS).to receive(:expire)
        
        MilestoneService.award_milestone(123, milestone_data)
        
        expect(xp_log_call).to include(250)  # explorer = 250 XP
      end
    end
    
    context 'with Redis available' do
      it 'caches recent milestones' do
        allow(DB).to receive(:execute)
        
        expect(REDIS).to receive(:lpush).with(/user:123:recent_milestones/, anything)
        expect(REDIS).to receive(:ltrim).with(/user:123:recent_milestones/, 0, 9)
        expect(REDIS).to receive(:expire).with(/user:123:recent_milestones/, 30 * 86400)
        
        MilestoneService.award_milestone(123, milestone_data)
      end
    end
    
    context 'without database' do
      it 'returns without error when user_id is nil' do
        result = MilestoneService.award_milestone(nil, milestone_data)
        expect(result).to be_nil
      end
    end
    
    context 'when database error occurs' do
      it 'returns false and logs error' do
        allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
        
        expect {
          result = MilestoneService.award_milestone(123, milestone_data)
          expect(result).to be false
        }.to output(/Milestone award error/).to_stdout
      end
    end
  end
  
  describe '.get_earned_milestones' do
    let(:earned_milestones) do
      [
        {
          'achievement_data' => '{"badge":"explorer","title":"🌟 Meme Explorer!"}',
          'earned_at' => '2026-05-01 12:00:00'
        },
        {
          'achievement_data' => '{"badge":"getting_started","title":"🎉 First 5!"}',
          'earned_at' => '2026-04-15 10:00:00'
        }
      ]
    end
    
    it 'returns earned milestones for user' do
      allow(DB).to receive(:execute).with(
        /SELECT achievement_data, earned_at FROM user_achievements/,
        [123]
      ).and_return(earned_milestones)
      
      result = MilestoneService.get_earned_milestones(123)
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first['badge']).to eq('explorer')
      expect(result.first['earned_at']).to eq('2026-05-01 12:00:00')
    end
    
    it 'returns empty array when no milestones' do
      allow(DB).to receive(:execute).and_return([])
      
      result = MilestoneService.get_earned_milestones(123)
      expect(result).to eq([])
    end
    
    it 'returns empty array when user_id is nil' do
      result = MilestoneService.get_earned_milestones(nil)
      expect(result).to eq([])
    end
    
    it 'returns empty array on database error' do
      allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
      
      expect {
        result = MilestoneService.get_earned_milestones(123)
        expect(result).to eq([])
      }.to output(/Get milestones error/).to_stdout
    end
  end
  
  describe '.calculate_xp_reward' do
    it 'returns 50 XP for getting_started' do
      expect(MilestoneService.calculate_xp_reward('getting_started')).to eq(50)
    end
    
    it 'returns 100 XP for on_fire' do
      expect(MilestoneService.calculate_xp_reward('on_fire')).to eq(100)
    end
    
    it 'returns 250 XP for explorer' do
      expect(MilestoneService.calculate_xp_reward('explorer')).to eq(250)
    end
    
    it 'returns 500 XP for legendary_unlock' do
      expect(MilestoneService.calculate_xp_reward('legendary_unlock')).to eq(500)
    end
    
    it 'returns 1000 XP for century_club' do
      expect(MilestoneService.calculate_xp_reward('century_club')).to eq(1000)
    end
    
    it 'returns 2500 XP for meme_master' do
      expect(MilestoneService.calculate_xp_reward('meme_master')).to eq(2500)
    end
    
    it 'returns 5000 XP for meme_legend' do
      expect(MilestoneService.calculate_xp_reward('meme_legend')).to eq(5000)
    end
    
    it 'returns 10000 XP for meme_god' do
      expect(MilestoneService.calculate_xp_reward('meme_god')).to eq(10000)
    end
    
    it 'returns 100 XP for unknown badge' do
      expect(MilestoneService.calculate_xp_reward('unknown_badge')).to eq(100)
    end
  end
  
  describe 'MILESTONES constant' do
    it 'has 8 defined milestones' do
      expect(MilestoneService::MILESTONES.keys.length).to eq(8)
    end
    
    it 'has milestones in ascending order' do
      keys = MilestoneService::MILESTONES.keys
      expect(keys).to eq([5, 10, 25, 50, 100, 250, 500, 1000])
    end
    
    it 'each milestone has required fields' do
      MilestoneService::MILESTONES.each do |count, data|
        expect(data).to have_key(:badge)
        expect(data).to have_key(:title)
        expect(data).to have_key(:message)
        expect(data).to have_key(:reward_type)
      end
    end
  end
end
