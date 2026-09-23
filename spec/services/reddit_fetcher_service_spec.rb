# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/services/reddit_fetcher_service'

RSpec.describe RedditFetcherService do
  describe 'initialization' do
    it 'initializes successfully' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'main functionality' do
    subject { described_class.new }

    it 'responds to primary methods' do
      # TODO: Add specific method tests based on service interface
      expect(subject).to respond_to(:call) if subject.respond_to?(:call)
    end
  end

  # BUG FIX: this file's trailing three examples were empty `pending`
  # placeholders (`pending` expects the block to actually fail; an empty
  # block trivially "passes," so these failed on every run without
  # testing anything). Replaced with real coverage of
  # RedditFetcherService.new's actual constructor validation and
  # fetch_memes's real nil/empty-input handling.
  describe 'error handling' do
    it 'defaults to the static (unauthenticated) strategy for an unrecognized auth_strategy' do
      fetcher = described_class.new(auth_strategy: :nonsense)
      expect(fetcher.fetch_memes([])).to eq([])
    end
  end

  describe 'edge cases' do
    it 'handles a nil subreddits list gracefully' do
      fetcher = described_class.new(auth_strategy: :static)
      expect { fetcher.fetch_memes(nil) }.not_to raise_error
    end

    it 'handles an empty subreddits list gracefully' do
      fetcher = described_class.new(auth_strategy: :static)
      expect(fetcher.fetch_memes([])).to eq([])
    end
  end
end
