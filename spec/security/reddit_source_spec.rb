require_relative '../spec_helper'
require_relative '../../lib/security/reddit_source'

RSpec.describe RedditSource do
  it 'normalizes real Reddit post links without external query parameters' do
    expect(described_class.path('/r/funny/comments/abc123/title/')).to eq('/r/funny/comments/abc123/title/')
    expect(described_class.path('https://old.reddit.com/r/funny/comments/abc123/title/?track=1')).to eq('/r/funny/comments/abc123/title/')
  end

  it 'rejects foreign hosts, ambiguous paths and attribute injection' do
    ['https://reddit.com.attacker.example/r/funny/comments/abc123/', '//attacker.example/r/funny/comments/abc123/',
      'javascript:alert(1)', '/r/funny', '/r/funny/comments/a/" onclick="bad', nil].each do |value|
      expect(described_class.path(value)).to be_nil
    end
  end
end