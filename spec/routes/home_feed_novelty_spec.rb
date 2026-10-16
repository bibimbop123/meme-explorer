require_relative '../spec_helper'

RSpec.describe 'Homepage novelty continuity' do
  let(:identity) { SecureRandom.hex(32) }
  let(:pool) { 3.times.map { |i| { 'url' => "/images/funny1.jpeg?novelty=#{i}", 'title' => "Novelty #{i}", 'subreddit' => 'cats' } } }

  before do
    set_session(feed_session_id: identity)
    allow_any_instance_of(MemeExplorer::App).to receive(:random_memes_pool).and_return(pool)
  end

  after { MemeExplorer::ViewingHistoryService.clear_history(identity) }

  it 'does not bypass recent selection history on repeated homepage visits' do
    urls = 3.times.map do
      get '/'
      expect(last_response.status).to eq(200)
      last_response.body[/data-meme-url="([^"]+)"/, 1]
    end
    expect(urls.compact.uniq.size).to eq(3)
    get '/'
    expect(last_response.body).to include("data-meme-url=\"#{urls.first}\"")
    expect(last_response.body).not_to include('id="feed-supply-status" role="status" hidden')
    expect(MemeExplorer::ViewingHistoryService.seen_count(identity)).to eq(3)
  end

  it 'selects newly available inventory before replaying old content' do
    pool.each { |m| MemeExplorer::ViewingHistoryService.mark_seen(identity, m['url']) }
    pool << { 'url' => '/images/funny1.jpeg?new-arrival=1', 'title' => 'Arrival', 'subreddit' => 'cats' }
    get '/'
    expect(last_response.body).to include('data-meme-url="/images/funny1.jpeg?new-arrival=1"')
    expect(last_response.body).to include('id="feed-supply-status" role="status" hidden')
  end

  it 'keeps unseen-first continuity for an authenticated homepage session' do
    user_id = create_test_user('home-novelty-account@example.test')
    set_session(feed_session_id: identity, user_id: user_id)
    urls = 3.times.map do
      get '/'
      expect(last_response.status).to eq(200)
      last_response.body[/data-meme-url="([^"]+)"/, 1]
    end
    expect(urls.compact.uniq.size).to eq(3)
    expect(MemeExplorer::ViewingHistoryService.seen_count(identity)).to eq(3)
  end
end