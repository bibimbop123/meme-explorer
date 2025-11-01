# app.rb
# -----------------------
# Core dependencies
# -----------------------
require "sinatra/base"
require "puma"
require "yaml"
require "json"
require "redis"
require "rack/attack"
require "securerandom"
require "uri"
require "time"
require "active_support"
require "active_support/cache"
require "sqlite3"
require "net/http"
require "thread"

require_relative "./db/setup"

$VERBOSE = nil # suppress warnings

# -----------------------
# Main App
# -----------------------
class MemeExplorer < Sinatra::Base
  # -----------------------
  # Redis & DB
  # -----------------------
  REDIS_URL = ENV.fetch("REDIS_URL", "rediss://red-d42v6u24d50c73a5goqg:UD3EpN1aQXznpIRseNj0ULS0qRNo8SvS@oregon-keyvalue.render.com:6379")
  REDIS = begin
    Redis.new(url: REDIS_URL)
  rescue
    nil
  end
  DB = ::DB

  # -----------------------
  # Rack::Attack
  # -----------------------
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL) if REDIS
  class Rack::Attack
    safelist("allow-localhost") { |req| ["127.0.0.1", "::1"].include?(req.ip) }
    throttle("req/ip", limit: 60, period: 60) { |req| req.ip unless req.path.start_with?("/assets") }
    self.throttled_responder = lambda do |_env|
      [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests" }.to_json]]
    end
  end
  use Rack::Attack

  # -----------------------
  # Constants
  # -----------------------
  POPULAR_SUBREDDITS = YAML.load_file("data/subreddits.yml") rescue {} # or inline hash
  ALL_POPULAR_SUBS = POPULAR_SUBREDDITS.values.flatten.freeze
  MEME_CACHE = {}
  MEMES = YAML.load_file("data/memes.yml") rescue []
  METRICS = Hash.new(0).merge(avg_request_time_ms: 0.0)

  # -----------------------
  # Configuration
  # -----------------------
  configure do
    set :server, :puma
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) }

    Thread.new do
      loop do
        begin
          REDIS&.setex("memes:latest", 180, MEMES.to_json)
        rescue => e
          puts "Redis error: #{e.message}"
        end
        sleep 180
      end
    end
  end

  # -----------------------
  # Request Lifecycle
  # -----------------------
  before do
    @start_time = Time.now
    @seen_memes = request.cookies["seen_memes"] ? JSON.parse(request.cookies["seen_memes"]) : []
    session[:liked_memes] ||= []
    session[:meme_history] ||= []
    session[:meme_index] ||= -1
  end

  after do
    duration = ((Time.now - @start_time) * 1000).round(2)
    METRICS[:total_requests] += 1
    total = METRICS[:total_requests]
    avg = METRICS[:avg_request_time_ms]
    METRICS[:avg_request_time_ms] = ((avg * (total - 1)) + duration) / total.to_f

    response.set_cookie(
      "seen_memes",
      value: @seen_memes.to_json,
      path: "/",
      expires: Time.now + 60 * 60 * 24 * 30,
      httponly: true
    )
  end

  # -----------------------
  # Helpers
  # -----------------------
  helpers do
    def meme_image_src(m)
      m["file"] || m["url"] || "/images/placeholder.png"
    end
  
    def get_cached_memes
      cached = REDIS&.get("memes:latest")
      if cached
        METRICS[:cache_hits] += 1
        JSON.parse(cached)
      else
        MEME_CACHE[:memes] ||= MEMES
      end
    rescue
      MEME_CACHE[:memes] ||= MEMES
    end
  
    def flatten_memes
      (get_cached_memes.values rescue []).flatten.map { |m| m["subreddit"] ||= "local"; m }
    end
  
    def fetch_fresh_memes(batch_size: 100)
      if MEME_CACHE[:fetched_at] && Time.now - MEME_CACHE[:fetched_at] < 180
        return MEME_CACHE[:memes]
      end
  
      MEME_CACHE[:memes] ||= []
      subreddits = POPULAR_SUBREDDITS.values.flatten.sample(150)
      results = []
      threads = []
  
      subreddits.each_slice(10) do |slice|
        slice.each do |sub|
          threads << Thread.new do
            begin
              url = URI("https://meme-api.com/gimme/#{sub}/#{batch_size}")
              res = Net::HTTP.get(url)
              memes = JSON.parse(res)["memes"] || []
              memes.each do |m|
                results << { "title" => m["title"], "url" => m["url"], "subreddit" => m["subreddit"] }
              end
            rescue => e
              puts "Error fetching #{sub}: #{e.message}"
            end
          end
        end
        threads.each(&:join)
        threads.clear
      end
  
      MEME_CACHE[:memes] = results.uniq { |m| m["url"] || m["file"] }
      MEME_CACHE[:fetched_at] = Time.now
      REDIS&.setex("memes:latest", 300, MEME_CACHE[:memes].to_json) rescue nil
      MEME_CACHE[:memes]
    end
  
    def navigate_meme(direction: "next")
      memes = safe_db_exec("SELECT * FROM meme_stats ORDER BY updated_at DESC")
      return nil if memes.nil? || memes.empty?
  
      index = session[:current_meme_index] || 0
  
      case direction
      when "next"
        index = (index + 1) % memes.size
      when "prev"
        index = (index - 1) % memes.size
      end
  
      session[:current_meme_index] = index
      memes[index]
    end
  
    # -----------------------
    # Additional helper methods
    # -----------------------
    def increment_view(file, title:, subreddit:)
      DB.execute("INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)", [file, title, subreddit])
      DB.execute("UPDATE meme_stats SET views = views + 1 WHERE url = ?", [file])
    end
  
    def like_meme(file)
      DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [file])
      session[:liked_memes] << file unless session[:liked_memes].include?(file)
    end
  
    def safe_db_exec(sql, params = [])
      DB.execute(sql, params)
    rescue SQLite3::Exception => e
      puts "DB error: #{e.message}"
      nil
    end
  end
  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    @meme = navigate_meme(direction: "next")
    halt 404, "No memes found!" unless @meme
    @image_src = @meme["url"]
    erb :random
  end

  get "/random" do
    @meme = navigate_meme(direction: "next")
    halt 404, "No memes found!" unless @meme
    @image_src = @meme["url"]
    erb :random
  end

  get "/random.json" do
    @meme = navigate_meme(direction: "next")
    halt 404, { error: "No memes found" }.to_json unless @meme
    content_type :json
    @meme.to_json
  end

  post "/like" do
    key = params[:url] || params[:file]
    halt 400, { error: "Missing meme URL" }.to_json unless key

    session[:liked_memes] ||= []
    existing = DB.execute("SELECT * FROM meme_stats WHERE url = ?", [key]).first
    DB.execute("INSERT INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)", [key, "Unknown Title", "Unknown Subreddit"]) if existing.nil?

    if session[:liked_memes].include?(key)
      session[:liked_memes].delete(key)
      DB.execute("UPDATE meme_stats SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END WHERE url = ?", [key])
      liked = false
    else
      like_meme(key)
      liked = true
    end

    likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [key]).first&.[]("likes") || 0
    content_type :json
    { liked: liked, likes: likes, url: key }.to_json
  end

  get "/trending" do
    db_memes = DB.execute("SELECT url, title, subreddit, views, likes, (likes * 2 + views) AS score FROM meme_stats")
                 .map { |r| r.transform_keys(&:to_s) }

    local_memes = flatten_memes.map do |m|
      {
        "title" => m["title"],
        "file" => m["file"],
        "subreddit" => "local",
        "likes" => DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0,
        "views" => DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0,
        "score" => (DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0) * 2 +
                   (DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0)
      }
    end

    combined = (db_memes + local_memes).uniq { |m| m["url"] || m["file"] }
    @memes = combined.sort_by { |m| -m["score"] }.first(20)
    erb :trending
  end

  get "/category/:category" do
    category = params[:category].to_sym
    halt 404, { error: "Category not found" }.to_json unless POPULAR_SUBREDDITS.key?(category)

    subreddits = POPULAR_SUBREDDITS[category]
    memes = fetch_fresh_memes(batch_size: 50).select { |m| subreddits.include?(m["subreddit"]) }
    content_type :json
    memes.to_json
  end

  # -----------------------
  # New category routes
  # -----------------------
  get "/category/:name" do
    @category_name = params[:name]
    @memes = get_cached_memes[@category_name] || []
    erb :category, layout: :layout
  end

  get "/category/:name/meme/:title" do
    @category_name = params[:name]
    @meme = (get_cached_memes[@category_name] || []).find do |m|
      URI.encode_www_form_component(m["title"]) == params[:title]
    end
    @image_src = @meme ? @meme["file"] : "/images/placeholder.png"
    @views = @meme ? DB.execute("SELECT views FROM meme_stats WHERE url = ?", [@image_src]).first&.first || 0 : 0
    erb :random, layout: :layout
  end

  get "/search" do
    query = params[:q]&.downcase
    memes = (DB.execute("SELECT * FROM meme_stats").map { |r| r.transform_keys(&:to_s) } + flatten_memes)
            .uniq { |m| m["url"] || m["file"] }
            .select { |m| m["title"].to_s.downcase.include?(query.to_s) }
    content_type :json
    memes.to_json
  end

  get "/metrics.json" do
    total_memes = DB.get_first_value("SELECT COUNT(*) FROM meme_stats") || 0
    total_likes = DB.get_first_value("SELECT SUM(likes) FROM meme_stats") || 0
    total_views = DB.get_first_value("SELECT SUM(views) FROM meme_stats") || 0

    avg_likes = total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0
    avg_views = total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0

    content_type :json
    {
      total_memes: total_memes,
      total_likes: total_likes,
      total_views: total_views,
      avg_likes: avg_likes,
      avg_views: avg_views
    }.to_json
  end

  get "/metrics" do
    MEME_CACHE ||= {}
    REDIS ||= begin
      begin
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).tap(&:ping)
      rescue => e
        puts "Warning: Redis not available - #{e.class}: #{e.message}"
        nil
      end
    end
    METRICS ||= {}
  
    # -----------------------
    # Defaults
    # -----------------------
    @last_batch          = (MEME_CACHE[:fetched_at] || Time.now).iso8601
    @total_memes         = 0
    @total_likes         = 0
    @total_views         = 0
    @memes_with_no_likes = 0
    @memes_with_no_views = 0
    @redis_views         = 0
    @redis_likes         = 0
    @redis_no_views      = 0
    @redis_no_likes      = 0
    @avg_likes           = 0
    @avg_views           = 0
    @avg_request_time_ms = 0
    @total_requests      = 0
    @cache_hits          = 0
    @cache_misses        = 0
    @api_calls           = 0
    @tier1_calls         = 0
    @tier2_calls         = 0
    @tier3_calls         = 0
    @top_memes           = []
    @top_subreddits      = []
  
    begin
      # -----------------------
      # DB Metrics
      # -----------------------
      if defined?(DB) && DB
        db_count      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats")&.first
        db_sum_likes  = safe_db_exec("SELECT SUM(likes) AS sum FROM meme_stats")&.first
        db_sum_views  = safe_db_exec("SELECT SUM(views) AS sum FROM meme_stats")&.first
        no_likes      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats WHERE likes = 0")&.first
        no_views      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats WHERE views = 0")&.first
  
        @total_memes         = (db_count&.dig("count") || 0).to_i
        @total_likes         = (db_sum_likes&.dig("sum") || 0).to_i
        @total_views         = (db_sum_views&.dig("sum") || 0).to_i
        @memes_with_no_likes = (no_likes&.dig("count") || 0).to_i
        @memes_with_no_views = (no_views&.dig("count") || 0).to_i
  
        # Top 10 memes by score (likes*2 + views)
        top_memes_data = safe_db_exec("
          SELECT title, subreddit, url, likes, views, (likes*2 + views) AS score
          FROM meme_stats
          ORDER BY score DESC
          LIMIT 10
        ")
        @top_memes = top_memes_data.map { |m| m.transform_keys(&:to_s) } if top_memes_data
  
        # Top 10 subreddits by total likes
        top_subreddit_data = safe_db_exec("
          SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
          FROM meme_stats
          GROUP BY subreddit
          ORDER BY total_likes DESC
          LIMIT 10
        ")
        @top_subreddits = top_subreddit_data.map { |s| s.transform_keys(&:to_s) } if top_subreddit_data
      end
  
      # -----------------------
      # Redis Metrics (sync with DB)
      # -----------------------
      if REDIS
        REDIS.set("memes:views", @total_views)
        REDIS.set("memes:likes", @total_likes)
        REDIS.set("memes:no_views", @memes_with_no_views)
        REDIS.set("memes:no_likes", @memes_with_no_likes)
  
        @redis_views    = REDIS.get("memes:views").to_i
        @redis_likes    = REDIS.get("memes:likes").to_i
        @redis_no_views = REDIS.get("memes:no_views").to_i
        @redis_no_likes = REDIS.get("memes:no_likes").to_i
      end
  
      # -----------------------
      # Averages & Other Metrics
      # -----------------------
      @avg_likes           = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
      @avg_views           = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0
      @avg_request_time_ms = METRICS[:avg_request_time_ms].to_f.round(2) rescue 0
      @total_requests      = METRICS[:total_requests] || 0
      @cache_hits          = METRICS[:cache_hits] || 0
      @cache_misses        = METRICS[:cache_misses] || 0
      @api_calls           = MEME_CACHE[:api_calls] || 0
      @tier1_calls         = MEME_CACHE[:tier1_calls] || 0
      @tier2_calls         = MEME_CACHE[:tier2_calls] || 0
      @tier3_calls         = MEME_CACHE[:tier3_calls] || 0
  
    rescue => e
      puts "Metrics error: #{e.class}: #{e.message}"
      puts e.backtrace.join("\n")
    end
  
    erb :metrics
  end
  
  
  # -----------------------
  # Start server
  # -----------------------
  run! if app_file == $0
end
