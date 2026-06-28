# frozen_string_literal: true
require_relative '../spec_helper'
require_relative '../../app/workers/image_health_worker'

RSpec.describe ImageHealthWorker do
  let(:worker) { described_class.new }

  describe '#perform with empty cache' do
    before { allow(MemeExplorer::App::MEME_CACHE).to receive(:get).with(:memes).and_return([]) }

    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end
  end

  describe '#perform with memes in cache' do
    before do
      memes = [{ 'url' => 'https://i.redd.it/test.jpg', 'title' => 'Test' }]
      allow(MemeExplorer::App::MEME_CACHE).to receive(:get).with(:memes).and_return(memes)
      allow(MemeExplorer::App::MEME_CACHE).to receive(:set)
      allow(ImageHealthService).to receive(:blacklisted?).and_return(false)
    end

    it 'executes without raising' do
      expect { worker.perform }.not_to raise_error
    end
  end

  it 'handles cache errors without re-raising' do
    allow(MemeExplorer::App::MEME_CACHE).to receive(:get).and_raise(RuntimeError, 'cache error')
    expect { worker.perform }.not_to raise_error
  end

  describe 'Sidekiq configuration' do
    it 'uses the low_priority queue' do
      expect(described_class.sidekiq_options_hash['queue'].to_s).to eq('low_priority')
    end
  end
end
