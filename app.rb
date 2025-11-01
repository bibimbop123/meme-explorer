# -----------------------
# Core dependencies
# -----------------------
require "sinatra/base"
require "puma"  # Keep this to ensure Puma is available as the server backend
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

require_relative "./db/setup"

$VERBOSE = nil  # Suppress redefinition warnings in dev

# -----------------------
# Main App
# -----------------------
class MemeExplorer < Sinatra::Base
  # -----------------------
  # Redis & Config
  # -----------------------
  REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  REDIS = Redis.new(url: REDIS_URL)
  DB = ::DB  # Use DB connection from db/setup.rb

  # -----------------------
  # Rack::Attack Setup
  # -----------------------
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL)
  class Rack::Attack
    safelist("allow-localhost") { |req| ["127.0.0.1", "::1"].include?(req.ip) }
    throttle("req/ip", limit: 60, period: 60) { |req| req.ip unless req.path.start_with?("/assets") }

    self.throttled_responder = lambda do |_env|
      [429, { "Content-Type" => "application/json" },
       [{ error: "Too many requests. Please slow down." }.to_json]]
    end
  end

  # -----------------------
  # Constants
  # -----------------------
  POPULAR_SUBREDDITS = {
    funny_memes: [
      "funny", "memes", "dankmemes", "PrequelMemes", "bonehurtingjuice",
      "okbuddyretard", "ComedyCemetery", "me_irl", "teenagers", "Animemes",
      "surrealmemes", "2meirl4meirl", "shittylifeprotips", "ProgrammerHumor",
      "HistoryMemes"
    ],
    wholesome: [
      "wholesomememes", "MadeMeSmile", "Eyebleach", "aww", "AnimalsBeingBros",
      "rarepuppers", "HumansBeingBros", "WholesomeGifs", "GetMotivated",
      "UpliftingNews", "nonononoyes"
    ],
    tech_cs: [
      "coding", "javascript", "python", "ruby", "programming", "MachineLearning",
      "computerscience", "cscareerquestions", "techmemes", "devops", "learnprogramming",
      "frontend", "backend", "webdev", "softwareengineering", "opensource"
    ],
    finance_business: [
      "stocks", "wallstreetbets", "investing", "financialindependence",
      "businesshub", "economics", "Entrepreneur", "personalfinance",
      "valueinvesting", "CryptoCurrency", "StockMarketMemes", "FinanceMemes"
    ],
    gaming_entertainment: [
      "gaming", "gamephysics", "pcgaming", "boardgames", "movies", "television",
      "Marvel", "StarWars", "anime", "memesaboutgames"
    ]
  }.freeze
  ALL_POPULAR_SUBS = POPULAR_SUBREDDITS.values.flatten.freeze

  MEME_CACHE = {}
  MEMES = YAML.load_file("data/memes.yml")
  METRICS = Hash.new(0).merge(avg_request_time_ms: 0.0)

  # -----------------------
  # Configuration
  # -----------------------
  configure do
    set :server, :puma
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) }

    # Periodically refresh Redis cache
    Thread.new do
      loop do
        REDIS.setex("memes:latest", 180, MEMES.to_json)
        sleep 180
      end
    end
  end

  use Rack::Attack

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
    def meme_image_src(meme)
      meme["file"] || meme["url"] || "/images/placeholder.png"
    end

    def get_cached_memes
      cached = REDIS.get("memes:latest")
      if cached
        METRICS[:cache_hits] += 1
        JSON.parse(cached)
      else
        METRICS[:cache_misses] += 1
        REDIS.setex("memes:latest", 180, MEMES.to_json)
        MEMES
      end
    rescue
      MEMES
    end

    def flatten_memes
      (get_cached_memes.values).flatten.map { |m| m["subreddit"] ||= "local"; m }
    end

    def weighted_sample(memes)
      memes.flat_map { |m|
        key = m["file"] || m["url"]
        session[:liked_memes].include?(key) ? [m] * 3 : [m]
      }.sample
    end

    def fetch_fresh_memes(batch_size = 78)
      if Time.now - (MEME_CACHE[:fetched_at] ||= Time.at(0)) > 120
        MEME_CACHE[:memes] = POPULAR_SUBREDDITS.values.flatten.sample(50).flat_map do |sub|
          2.times.map do
            url = URI("https://meme-api.com/gimme/#{sub}/#{batch_size}")
            begin
              JSON.parse(Net::HTTP.get(url))["memes"] || []
            rescue
              []
            end.map { |m| { "title" => m["title"], "url" => m["url"], "subreddit" => m["subreddit"] } }
          end.flatten
        end.uniq { |m| m["url"] || m["file"] }
        MEME_CACHE[:fetched_at] = Time.now
      end
      MEME_CACHE[:memes]
    end

    def tiered_random(level: 3)
      session[:seen_memes] ||= []

      db_memes = DB.execute("SELECT rowid, *, (likes * 2 + views) AS score FROM meme_stats").map { |r| r.transform_keys(&:to_s) }
      all_memes = db_memes.uniq { |m| m["url"] || m["file"] }
      

      case level
      when 1
        all_memes.sample
      when 2
        weighted_pool = all_memes.flat_map do |m|
          key = m["file"] || m["url"]
          session[:liked_memes]&.include?(key) ? [m] * 3 : [m]
        end
        weighted_pool.sample
      else
        unseen = all_memes.reject { |m| session[:seen_memes].include?(m["url"] || m["file"]) }
        pool = unseen.any? ? unseen : all_memes

        weighted_pool = pool.flat_map do |m|
          key = m["file"] || m["url"]
          session[:liked_memes]&.include?(key) ? [m] * 3 : [m]
        end
        weighted_pool.sample
      end
    end

    def increment_view(file, title:, subreddit:)
      DB.execute("INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)", [file, title, subreddit])
      DB.execute("UPDATE meme_stats SET views = views + 1 WHERE url = ?", [file])
    end

    def like_meme(file)
      DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [file])
    end

    def next_meme
      meme = tiered_random(level: 3)
      return nil unless meme

      key = meme["file"] || meme["url"]
      session[:seen_memes] << key
      session[:seen_memes] = session[:seen_memes].last(200)

      meme
    end

    def push_meme_history(meme)
      session[:meme_history] ||= []
      session[:meme_index] ||= -1

      current_key = meme["url"] || meme["file"]
      if session[:meme_history][session[:meme_index]] != current_key
        session[:meme_history] = session[:meme_history][0..session[:meme_index]]
        session[:meme_history] << current_key
        session[:meme_index] = session[:meme_history].size - 1
      end

      session[:meme_history] = session[:meme_history].last(200)
    end

    def meme_from_history(offset = 0)
      session[:meme_history] ||= []
      session[:meme_index] ||= -1

      new_index = session[:meme_index] + offset
      return nil if new_index < 0 || new_index >= session[:meme_history].size

      session[:meme_index] = new_index
      key = session[:meme_history][new_index]

      meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", [key]).first
      meme ||= flatten_memes.find { |m| (m["file"] || m["url"]) == key }
      meme
    end

    # -----------------------
    # Unified helper for /random & /random.json
    # -----------------------
    def meme_key(m)
      m["url"] || m["file"]
    end
  
    def navigate_meme(direction: "next")
      session[:meme_history] ||= []
      session[:meme_index] ||= -1
      session[:liked_memes] ||= []
  
      if direction == "prev"
        # Navigate backward safely
        session[:meme_index] = [session[:meme_index] - 1, 0].max
      else
        # Fetch memes from DB + YAML cache
        db_memes = DB.execute("SELECT *, (likes * 2 + views) AS score FROM meme_stats").map { |r| r.transform_keys(&:to_s) }
        fresh_memes = fetch_fresh_memes(10)
        yaml_memes = flatten_memes
        candidates = (db_memes + fresh_memes + yaml_memes).uniq { |m| meme_key(m) }
  
        # Filter unseen memes
        seen_keys = session[:meme_history].map { |m| meme_key(m) }
        unseen = candidates.reject { |m| seen_keys.include?(meme_key(m)) }
        pool = unseen.any? ? unseen : candidates
  
        # Weighted sampling: liked memes appear 3x
        weighted_pool = pool.flat_map do |m|
          session[:liked_memes]&.include?(meme_key(m)) ? [m] * 3 : [m]
        end
  
        # Pick a random meme safely
        meme = weighted_pool.sample
        return nil unless meme
  
        # Push to history
        session[:meme_history] << meme
        session[:meme_index] = session[:meme_history].size - 1
      end
  
      # Return current meme
      session[:meme_history][session[:meme_index]]
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    redirect "/random"
  end

  get "/random" do
    @meme = navigate_meme(direction: params[:direction] || "next")
    halt 404, "No memes found!" unless @meme
  
    # Increment Redis counters safely
    if REDIS && @meme
      REDIS.incr("memes:views")
      REDIS.incr("memes:no_views") if (@meme["views"] || 0).to_i.zero?
      REDIS.incr("memes:likes")
      REDIS.incr("memes:no_likes") if (@meme["likes"] || 0).to_i.zero?
    end
  
    # Use 'url' if available, otherwise fallback to 'file'
    @image_src = @meme["url"] || @meme["file"] || "/images/placeholder.png"
    erb :random
  end
  
  
  get "/random.json" do
    @meme = navigate_meme(direction: params[:direction] || "next")
    halt 404, { error: "No memes found" }.to_json unless @meme
  
    content_type :json
  
    key = @meme["url"] || @meme["file"]
  
    {
      title: @meme["title"] || "Untitled",
      url: key || "/images/placeholder.png",
      subreddit: @meme["subreddit"] || "local",
      likes: (@meme["likes"] || 0).to_i,
      views: (@meme["views"] || 0).to_i,
      index: session[:meme_index],
      history_size: session[:meme_history]&.size || 0
    }.to_json
  end

  # -----------------------
  # Trending
  # -----------------------
  get "/trending" do
    db_memes = DB.execute("SELECT url, title, subreddit, views, likes, (likes * 2 + views) AS score FROM meme_stats")
                 .map { |r| r.transform_keys(&:to_s) }

    local_memes = flatten_memes.map do |m|
      {
        "title" => m["title"],
        "file" => m["file"],
        "subreddit" => "local",
        "likes" => (DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0),
        "views" => (DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0),
        "score" => ((DB.get_first_value("SELECT likes FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0) * 2) +
                   (DB.get_first_value("SELECT views FROM meme_stats WHERE url = ?", [m["file"] || m["url"]]) || 0)
      }
    end

    combined = (db_memes + local_memes).uniq { |m| m["url"] || m["file"] }
    @memes = combined.sort_by { |m| -m["score"] }.first(20)
    erb :trending
  end

  # -----------------------
  # Category routes
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
    @results = {}
    flatten_memes.each do |m|
      if query && m["title"].downcase.include?(query)
        @results[m["subreddit"]] = { title: m["title"], file: m["file"] }
      end
    end
    erb :search, layout: :layout
  end

  post "/like" do
    content_type :json
    url = params[:url]
    session[:liked_memes] ||= []

    meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", [url]).first

    if meme
      liked = session[:liked_memes].include?(url)
      new_likes = liked ? [meme["likes"] - 1, 0].max : meme["likes"] + 1
      DB.execute("UPDATE meme_stats SET likes = ? WHERE url = ?", [new_likes, url])

      liked ? session[:liked_memes].delete(url) : session[:liked_memes] << url
      { liked: !liked, likes: new_likes }.to_json
    else
      status 404
      { error: "Meme not found" }.to_json
    end
  end

  post "/like/:id" do
    meme_id = params[:id]
    
    # Update DB
    DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE id = ?", meme_id)
    
    # Update Redis
    if REDIS
      REDIS.incr("memes:likes")
      # If it was previously 0 likes, decrement no_likes counter
      likes = DB.execute("SELECT likes FROM meme_stats WHERE id = ?", meme_id).first["likes"].to_i
      REDIS.decr("memes:no_likes") if likes == 1
    end
  
    redirect back
  end
  

  # -----------------------
  # Metrics route
  # -----------------------
  get "/metrics" do
    MEME_CACHE ||= {}
    REDIS ||= begin
      begin
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
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
        db_count      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats").first
        db_sum_likes  = safe_db_exec("SELECT SUM(likes) AS sum FROM meme_stats").first
        db_sum_views  = safe_db_exec("SELECT SUM(views) AS sum FROM meme_stats").first
        no_likes      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats WHERE likes = 0").first
        no_views      = safe_db_exec("SELECT COUNT(*) AS count FROM meme_stats WHERE views = 0").first
  
        @total_memes         = db_count["count"].to_i
        @total_likes         = db_sum_likes["sum"].to_i
        @total_views         = db_sum_views["sum"].to_i
        @memes_with_no_likes = no_likes["count"].to_i
        @memes_with_no_views = no_views["count"].to_i
  
        # Top 10 memes by score (likes*2 + views)
        top_memes_data = safe_db_exec("
          SELECT title, subreddit, url, likes, views, (likes*2 + views) AS score
          FROM meme_stats
          ORDER BY score DESC
          LIMIT 10
        ")
        @top_memes = top_memes_data.map { |m| m.transform_keys(&:to_s) }
  
        # Top 10 subreddits by total likes
        top_subreddit_data = safe_db_exec("
          SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
          FROM meme_stats
          GROUP BY subreddit
          ORDER BY total_likes DESC
          LIMIT 10
        ")
        @top_subreddits = top_subreddit_data.map { |s| s.transform_keys(&:to_s) }
      end
  
      # -----------------------
      # Redis Metrics
      # -----------------------
      if REDIS
        # If Redis keys do not exist, optionally initialize them from DB
        REDIS.set("memes:views", @total_views) if REDIS.get("memes:views").nil?
        REDIS.set("memes:likes", @total_likes) if REDIS.get("memes:likes").nil?
        REDIS.set("memes:no_views", @memes_with_no_views) if REDIS.get("memes:no_views").nil?
        REDIS.set("memes:no_likes", @memes_with_no_likes) if REDIS.get("memes:no_likes").nil?
  
        @redis_views    = REDIS.get("memes:views").to_i
        @redis_likes    = REDIS.get("memes:likes").to_i
        @redis_no_views = REDIS.get("memes:no_views").to_i
        @redis_no_likes = REDIS.get("memes:no_likes").to_i
      end
  
      # -----------------------
      # Averages & Other Metrics
      # -----------------------
      @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
      @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0
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
    end
  
    erb :metrics
  end
  

  # -----------------------
  # Helpers for safe DB execution
  # -----------------------
  def safe_db_exec(query)
    DB.execute(query)
  rescue SQLite3::Exception => e
    puts "DB Error: #{e.class}: #{e.message}"
    []
  end

  # -----------------------
  # Start the server if run directly
  # -----------------------
  run! if app_file == $0
end
