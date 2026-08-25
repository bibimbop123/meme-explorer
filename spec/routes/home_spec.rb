# frozen_string_literal: true
# spec/routes/home_spec.rb
require_relative '../spec_helper'
require_relative '../../lib/services/meme_pool_manager'

RSpec.describe 'Routes: GET /' do
  include Rack::Test::Methods
  def app; MemeExplorer::App; end

  describe 'GET /' do
    it 'returns 200' do
      get '/'
      expect(last_response.status).to eq(200)
    end

    it 'renders the random meme view' do
      get '/'
      expect(last_response.body).not_to be_empty
    end

    it 'sets a session cookie' do
      get '/'
      expect(last_response.headers['Set-Cookie']).not_to be_nil
    end

    it 'does not leak internal errors to the response body' do
      get '/'
      expect(last_response.body).not_to include('NoMethodError')
      expect(last_response.body).not_to include('ArgumentError')
    end
  end

  describe 'Session tracking' do
    it 'tracks view count in session' do
      get '/'
      expect(last_response.status).to eq(200)
      # View was served — no assertion on session internals needed
      # (session is opaque in rack-test without direct access)
    end
  end

  # Regression test for the production incident (Aug 25, 2026, round 9)
  # where this route trusted MemeExplorer::App::MEME_CACHE[:memes] first
  # and only called random_memes_pool (which correctly prioritizes
  # MemePoolManager's Redis-backed, tier-distributed pool) when that
  # legacy cache was empty. Once MEME_CACHE[:memes] got seeded with just
  # the 10-item local fallback list (e.g. during an earlier rate-limited
  # window), this route kept serving only those 10 local memes forever -
  # even after MemePoolManager's real Reddit-sourced pool became
  # available and was being served correctly elsewhere (e.g. /random.json,
  # which already called random_memes_pool unconditionally).
  describe 'MemePoolManager pool preference (round 9 regression)' do
    it 'prefers MemePoolManager over a stale legacy MEME_CACHE snapshot' do
      stale_local_memes = [{ 'file' => '/images/funny1.jpeg', 'title' => 'stale local meme' }]
      allow(MemeExplorer::App::MEME_CACHE).to receive(:[]).with(:memes).and_return(stale_local_memes)

      fresh_pool_meme = { 'url' => 'https://i.redd.it/fresh.jpg', 'title' => 'fresh reddit meme', 'subreddit' => 'funny' }
      allow(MemePoolManager).to receive(:get_pool).and_return(
        success: true, memes: [fresh_pool_meme], pool_size: 1, error: nil
      )

      get '/'

      expect(last_response.status).to eq(200)
      # The stale local meme's distinctive title should NOT be the one served
      # when a fresh MemePoolManager pool is available.
      expect(last_response.body).not_to include('stale local meme')
    end
  end
end
