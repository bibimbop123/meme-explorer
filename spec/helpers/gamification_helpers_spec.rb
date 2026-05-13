# spec/helpers/gamification_helpers_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/helpers/gamification_helpers'

class TestClass
  include GamificationHelpers
end

RSpec.describe GamificationHelpers do
  let(:helper) { TestClass.new }
  
  describe '#calculate_points' do
    it 'calculates points for likes' do
      points = helper.calculate_points(action: 'like')
      expect(points).to be > 0
    end
    
    it 'calculates points for shares' do
      points = helper.calculate_points(action: 'share')
      expect(points).to be > 0
    end
    
    it 'returns 0 for unknown actions' do
      points = helper.calculate_points(action: 'unknown')
      expect(points).to eq(0)
    end
  end
  
  describe '#get_level' do
    it 'returns level 1 for low points' do
      level = helper.get_level(points: 100)
      expect(level).to eq(1)
    end
    
    it 'increases level with more points' do
      level1 = helper.get_level(points: 100)
      level2 = helper.get_level(points: 1000)
      expect(level2).to be > level1
    end
    
    it 'handles zero points' do
      level = helper.get_level(points: 0)
      expect(level).to eq(1)
    end
  end
  
  describe '#get_badge' do
    it 'returns beginner badge for new users' do
      badge = helper.get_badge(points: 10)
      expect(badge).to include('Beginner').or eq('Newbie')
    end
    
    it 'returns advanced badges for high points' do
      badge = helper.get_badge(points: 10000)
      expect(badge).not_to include('Beginner')
    end
  end
  
  describe '#format_points' do
    it 'formats small numbers normally' do
      expect(helper.format_points(500)).to eq('500')
    end
    
    it 'formats large numbers with K' do
      expect(helper.format_points(5000)).to match(/5\.?\d*K/)
    end
    
    it 'formats very large numbers with M' do
      expect(helper.format_points(5000000)).to match(/5\.?\d*M/)
    end
  end
end
