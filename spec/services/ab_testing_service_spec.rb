# spec/services/ab_testing_service_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/ab_testing_service'

RSpec.describe ABTestingService do
  let(:experiment_data) do
    {
      'id' => 1,
      'name' => 'button_color_test',
      'description' => 'Test button colors',
      'variants' => '{"red": 0.5, "blue": 0.5}',
      'active' => true
    }
  end
  
  let(:inactive_experiment) do
    {
      'id' => 2,
      'name' => 'inactive_test',
      'description' => 'Inactive test',
      'variants' => '{"a": 0.5, "b": 0.5}',
      'active' => false
    }
  end
  
  before do
    # Mock DB to prevent actual database calls
    stub_const('DB', double('DB'))
  end
  
  describe '.get_variant' do
    context 'when experiment exists and is active' do
      it 'returns existing assignment' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['button_color_test']
        ).and_return([experiment_data])
        
        allow(DB).to receive(:execute).with(
          /SELECT variant FROM experiment_assignments/,
          [1, 'user123']
        ).and_return([{ 'variant' => 'red' }])
        
        variant = ABTestingService.get_variant('button_color_test', 'user123')
        expect(variant).to eq('red')
      end
      
      it 'assigns new variant when no existing assignment' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['button_color_test']
        ).and_return([experiment_data])
        
        allow(DB).to receive(:execute).with(
          /SELECT variant FROM experiment_assignments/,
          [1, 'user456']
        ).and_return([])
        
        allow(DB).to receive(:execute).with(
          /INSERT INTO experiment_assignments/,
          anything
        )
        
        variant = ABTestingService.get_variant('button_color_test', 'user456')
        expect(['red', 'blue']).to include(variant)
      end
      
      it 'uses consistent hashing for same user' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['button_color_test']
        ).and_return([experiment_data])
        
        allow(DB).to receive(:execute).with(
          /SELECT variant FROM experiment_assignments/,
          anything
        ).and_return([])
        
        allow(DB).to receive(:execute).with(
          /INSERT INTO experiment_assignments/,
          anything
        )
        
        variant1 = ABTestingService.get_variant('button_color_test', 'consistent_user')
        variant2 = ABTestingService.get_variant('button_color_test', 'consistent_user')
        
        # Same user should get same variant (via consistent hashing)
        expect(variant1).to eq(variant2)
      end
    end
    
    context 'when experiment is inactive' do
      it 'returns nil' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['inactive_test']
        ).and_return([inactive_experiment])
        
        variant = ABTestingService.get_variant('inactive_test', 'user123')
        expect(variant).to be_nil
      end
    end
    
    context 'when experiment does not exist' do
      it 'returns nil' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['nonexistent']
        ).and_return([])
        
        variant = ABTestingService.get_variant('nonexistent', 'user123')
        expect(variant).to be_nil
      end
    end
    
    context 'with invalid parameters' do
      it 'returns nil when experiment_name is nil' do
        variant = ABTestingService.get_variant(nil, 'user123')
        expect(variant).to be_nil
      end
      
      it 'returns nil when user_identifier is nil' do
        variant = ABTestingService.get_variant('test', nil)
        expect(variant).to be_nil
      end
    end
    
    context 'when database error occurs' do
      it 'returns nil and logs error' do
        allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
        
        expect {
          variant = ABTestingService.get_variant('test', 'user123')
          expect(variant).to be_nil
        }.to output(/Error getting variant/).to_stdout
      end
    end
  end
  
  describe '.track_conversion' do
    context 'when user has variant assignment' do
      it 'records conversion successfully' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['button_color_test']
        ).and_return([experiment_data])
        
        allow(DB).to receive(:execute).with(
          /SELECT variant FROM experiment_assignments/,
          [1, 'user123']
        ).and_return([{ 'variant' => 'red' }])
        
        allow(DB).to receive(:execute).with(
          /INSERT INTO experiment_conversions/,
          anything
        )
        
        result = ABTestingService.track_conversion(
          'button_color_test', 
          'user123', 
          'click',
          { button_id: 'main_cta' }
        )
        
        expect(result).to be true
      end
    end
    
    context 'when user has no assignment' do
      it 'returns false' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['button_color_test']
        ).and_return([experiment_data])
        
        allow(DB).to receive(:execute).with(
          /SELECT variant FROM experiment_assignments/,
          [1, 'user999']
        ).and_return([])
        
        result = ABTestingService.track_conversion('button_color_test', 'user999', 'click')
        expect(result).to be false
      end
    end
    
    context 'when experiment does not exist' do
      it 'returns false' do
        allow(DB).to receive(:execute).with(
          /SELECT \* FROM experiments/,
          ['nonexistent']
        ).and_return([])
        
        result = ABTestingService.track_conversion('nonexistent', 'user123', 'click')
        expect(result).to be false
      end
    end
    
    context 'with invalid parameters' do
      it 'returns false when experiment_name is nil' do
        result = ABTestingService.track_conversion(nil, 'user123', 'click')
        expect(result).to be false
      end
      
      it 'returns false when user_identifier is nil' do
        result = ABTestingService.track_conversion('test', nil, 'click')
        expect(result).to be false
      end
    end
  end
  
  describe '.get_stats' do
    it 'returns statistics for experiment' do
      allow(DB).to receive(:execute).with(
        /SELECT \* FROM experiments/,
        ['button_color_test']
      ).and_return([experiment_data])
      
      allow(DB).to receive(:execute).with(
        /SELECT variant, COUNT\(\*\) as count.*FROM experiment_assignments/,
        [1]
      ).and_return([
        { 'variant' => 'red', 'count' => 100 },
        { 'variant' => 'blue', 'count' => 95 }
      ])
      
      allow(DB).to receive(:execute).with(
        /SELECT variant, conversion_type, COUNT\(\*\) as count.*FROM experiment_conversions/,
        [1]
      ).and_return([
        { 'variant' => 'red', 'conversion_type' => 'click', 'count' => 15 },
        { 'variant' => 'blue', 'conversion_type' => 'click', 'count' => 20 }
      ])
      
      stats = ABTestingService.get_stats('button_color_test')
      
      expect(stats).to be_a(Hash)
      expect(stats[:experiment]).to eq(experiment_data)
      expect(stats[:results]['red'][:users]).to eq(100)
      expect(stats[:results]['red'][:conversions]).to eq(15)
      expect(stats[:results]['red'][:conversion_rate]).to eq(15.0)
      expect(stats[:results]['blue'][:users]).to eq(95)
      expect(stats[:results]['blue'][:conversion_rate]).to eq(21.05)
    end
    
    it 'returns nil when experiment does not exist' do
      allow(DB).to receive(:execute).with(
        /SELECT \* FROM experiments/,
        ['nonexistent']
      ).and_return([])
      
      stats = ABTestingService.get_stats('nonexistent')
      expect(stats).to be_nil
    end
  end
  
  describe '.create_experiment' do
    context 'with valid variants' do
      it 'creates experiment successfully' do
        variants = { 'control' => 0.5, 'variant_a' => 0.5 }
        
        allow(DB).to receive(:execute).with(
          /INSERT INTO experiments/,
          ['new_test', 'Test description', variants.to_json, false]
        )
        
        result = ABTestingService.create_experiment(
          'new_test',
          'Test description',
          variants,
          false
        )
        
        expect(result).to be true
      end
    end
    
    context 'with invalid variants' do
      it 'raises error when weights do not sum to 1.0' do
        variants = { 'a' => 0.3, 'b' => 0.3 }  # Sums to 0.6
        
        expect {
          ABTestingService.create_experiment('test', 'desc', variants)
        }.to raise_error(/Variant weights must sum to 1.0/)
      end
    end
    
    context 'when database error occurs' do
      it 'returns false and logs error' do
        variants = { 'a' => 0.5, 'b' => 0.5 }
        allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
        
        expect {
          result = ABTestingService.create_experiment('test', 'desc', variants)
          expect(result).to be false
        }.to output(/Error creating experiment/).to_stdout
      end
    end
  end
  
  describe '.toggle_experiment' do
    it 'activates experiment' do
      allow(DB).to receive(:execute).with(
        /UPDATE experiments SET active/,
        [true, 'button_color_test']
      )
      
      result = ABTestingService.toggle_experiment('button_color_test', true)
      expect(result).to be true
    end
    
    it 'deactivates experiment' do
      allow(DB).to receive(:execute).with(
        /UPDATE experiments SET active/,
        [false, 'button_color_test']
      )
      
      result = ABTestingService.toggle_experiment('button_color_test', false)
      expect(result).to be true
    end
    
    it 'returns false on database error' do
      allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
      
      expect {
        result = ABTestingService.toggle_experiment('test', true)
        expect(result).to be false
      }.to output(/Error toggling experiment/).to_stdout
    end
  end
  
  describe '.list_experiments' do
    it 'returns all experiments' do
      experiments = [
        experiment_data,
        inactive_experiment
      ]
      
      allow(DB).to receive(:execute).with(
        /SELECT \* FROM experiments ORDER BY created_at DESC/
      ).and_return(experiments)
      
      result = ABTestingService.list_experiments
      expect(result).to eq(experiments)
      expect(result.length).to eq(2)
    end
    
    it 'returns empty array on error' do
      allow(DB).to receive(:execute).and_raise(StandardError.new('DB error'))
      
      expect {
        result = ABTestingService.list_experiments
        expect(result).to eq([])
      }.to output(/Error listing experiments/).to_stdout
    end
  end
end
