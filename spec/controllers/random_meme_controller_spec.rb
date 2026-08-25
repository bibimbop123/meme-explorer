# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/controllers/random_meme_controller'

RSpec.describe MemeExplorer::RandomMemeController do
  let(:session) { { session_id: SecureRandom.uuid, meme_history: [] } }
  let(:user_id) { nil }
  let(:request_ip) { '127.0.0.1' }
  let(:sample_pool) do
    [
      { 'url' => 'https://example.com/meme1.jpg', 'title' => 'Meme One', 'subreddit' => 'funny', 'likes' => 5, 'views' => 20 },
      { 'url' => 'https://example.com/meme2.jpg', 'title' => 'Meme Two', 'subreddit' => 'memes', 'likes' => 1, 'views' => 3 }
    ]
  end

  before do
    # Isolate the controller from whichever live pool source happens to be
    # configured (MemePool / MEME_CACHE / Reddit fetch) so tests are
    # deterministic and don't depend on external services.
    allow_any_instance_of(described_class).to receive(:get_meme_pool).and_return(sample_pool)
  end

  # Regression coverage: this file used to have unconditional
  # `require_relative` calls for milestone_service / retention_service /
  # near_miss_service, none of which exist in this codebase (they were
  # removed in a prior cleanup), so simply loading this file raised a
  # LoadError before it could ever be used.
  it 'can be required without raising LoadError' do
    expect { load File.expand_path('../../lib/controllers/random_meme_controller.rb', __dir__) }.not_to raise_error
  end

  describe '.handle' do
    it 'returns a Result with a selected meme and display data' do
      result = described_class.handle(session: session, user_id: user_id, request_ip: request_ip)

      expect(result).to be_a(described_class::Result)
      expect(result.meme).not_to be_nil
      expect(result.image_src).to be_a(String)
      expect(result.likes).to eq(0)
    end

    it 'increments the session view count' do
      expect {
        described_class.handle(session: session, user_id: user_id, request_ip: request_ip)
      }.to change { session[:view_count] }.from(nil).to(1)
    end

    it 'falls back to a placeholder meme when the pool is empty' do
      allow_any_instance_of(described_class).to receive(:get_meme_pool).and_return([])

      result = described_class.handle(session: session, user_id: user_id, request_ip: request_ip)

      expect(result.meme).not_to be_nil
      expect(result.meme['title']).to eq('Welcome to Meme Explorer!')
    end

    it 'handles unexpected errors gracefully and still returns a usable result' do
      allow_any_instance_of(described_class).to receive(:get_meme_pool).and_raise(StandardError.new('boom'))

      result = described_class.handle(session: session, user_id: user_id, request_ip: request_ip)

      expect(result).to be_a(described_class::Result)
      expect(result.meme).not_to be_nil
      expect(result.image_src).to be_a(String)
    end

    it 'uses SimpleMemeSelector (not the removed DiversityEngineService) for meme selection' do
      expect(MemeExplorer::SimpleMemeSelector).to receive(:select_random_meme).and_call_original

      described_class.handle(session: session, user_id: user_id, request_ip: request_ip)
    end
  end
end
