# frozen_string_literal: true
# Local-only fixture server; never use as a deployment entry point.
require 'uri'
db = URI(ENV.fetch('DATABASE_URL', ''))
redis = URI(ENV.fetch('REDIS_URL', ''))
abort 'Explicit loopback test DB and disposable Redis 16379 required.' unless
  ENV['RACK_ENV'] == 'test' && %w[postgres postgresql].include?(db.scheme) &&
  %w[localhost 127.0.0.1].include?(db.host) && db.path.match?(/\A\/meme_explorer_[a-z_]*test\z/) && db.query.nil? &&
  redis.scheme == 'redis' && %w[localhost 127.0.0.1].include?(redis.host) && redis.port == 16379 && redis.path == '/0'
require 'dotenv'
$LOADED_FEATURES << 'dotenv/load.rb'
require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: false)
require 'sidekiq/testing'
Sidekiq::Testing.fake!
# Prevent inherited external integrations even when launched from a developer shell.
%w[SENTRY_DSN REDDIT_CLIENT_ID REDDIT_CLIENT_SECRET CDN_URL GOOGLE_ADSENSE_CLIENT MONETAG_ZONE_ID].each { |key| ENV.delete(key) }
ENV['DISABLE_ADS'] = 'true'
ENV['SESSION_SECRET'] = 'local-browser-fixture-only-' * 8
root = File.expand_path('..', __dir__)
require File.join(root, 'app')
class SearchService
  class << self
    alias_method :browser_original_search, :search
    def search(query, *args)
      return { success: true, results: [], query: query } if query == 'browser-no-matches & topic'
      browser_original_search(query, *args)
    end
  end
end
if (email = ENV['BROWSER_FIXTURE_ACCOUNT'])
  abort 'Invalid disposable browser account.' unless email.match?(/\Abrowser-[a-f0-9]{24}@example\.test\z/)
  abort 'Disposable browser account already exists.' if DB.get_first_value('SELECT id FROM users WHERE email = ?', [email])
  at_exit do
    uid = DB.get_first_value('SELECT id FROM users WHERE email = ?', [email])
    if uid
      DB.execute('DELETE FROM meme_activity_log WHERE user_id = ?', [uid])
      DB.execute('DELETE FROM users WHERE id = ?', [uid])
    end
  end
end
class MemePoolManager
  def self.get_pool(*)
    mode = Thread.current[:browser_fixture_media]
    if mode == 'gallery'
      images = %w[funny1.jpeg funny2.jpeg funny3.jpeg].map { |name| { 'url' => "/images/#{name}" } }
      meme = { 'url' => images.first['url'], 'title' => 'Browser gallery fixture', 'subreddit' => 'local',
        'is_gallery' => true, 'gallery_images' => images }
      return { success: true, memes: [meme], pool_size: 1 }
    end
    if mode == 'video'
      meme = { 'url' => '/videos/funny_clip.mp4', 'video_url' => '/videos/funny_clip.mp4',
        'media_type' => 'video', 'title' => 'Browser invalid-video fixture', 'subreddit' => 'local' }
      return { success: true, memes: [meme], pool_size: 1 }
    end
    memes = %w[funny1.jpeg funny2.jpeg funny3.jpeg].map do |name|
      { 'url' => "/images/#{name}", 'title' => "Browser fixture #{name}", 'subreddit' => 'local' }
    end
    { success: true, memes: memes, pool_size: memes.size }
  end
end
class BrowserFixtureMode
  def initialize(app); @app = app; end
  def call(env)
    Thread.current[:browser_fixture_media] = Rack::Request.new(env).params['fixture_media']
    @app.call(env)
  ensure
    Thread.current[:browser_fixture_media] = nil
  end
end
use BrowserFixtureMode
eval(File.read(File.join(root, 'config.ru')), binding, File.join(root, 'config.ru'))