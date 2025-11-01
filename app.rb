# app.rb
# -----------------------
# Core dependencies
# -----------------------
# app.rb
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
  POPULAR_SUBREDDITS = [
    # Funny / Meme-focused
    "funny", "memes", "dankmemes", "PrequelMemes", "bonehurtingjuice",
    "okbuddyretard", "ComedyCemetery", "me_irl", "teenagers", "Animemes",
    "surrealmemes", "2meirl4meirl", "ProgrammerHumor", "HistoryMemes", "shittylifeprotips",

    # Wholesome / Feel-good
    "wholesomememes", "MadeMeSmile", "Eyebleach", "aww", "AnimalsBeingBros",
    "rarepuppers", "HumansBeingBros", "WholesomeGifs", "GetMotivated",
    "UpliftingNews", "nonononoyes"
  ].freeze

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

    def fetch_fresh_memes(batch_size = 20)
      if Time.now - (MEME_CACHE[:fetched_at] ||= Time.at(0)) > 120
        MEME_CACHE[:memes] = POPULAR_SUBREDDITS.sample(8).flat_map do |sub|
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

    def tier_random(level: 3)
      case level
      when 1 then flatten_memes.sample
      when 2 then weighted_sample(flatten_memes)
      else
        local = flatten_memes
        all_candidates = (local + fetch_fresh_memes(10)).uniq { |m| m["url"] || m["file"] }
        unseen = all_candidates.reject { |m| @seen_memes.include?(m["url"] || m["file"]) }
        pool = unseen.any? ? unseen : all_candidates
        weighted_sample(pool)
      end
    end

    def increment_view(file, title:, subreddit:)
      DB.execute("INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)", [file, title, subreddit])
      DB.execute("UPDATE meme_stats SET views = views + 1 WHERE url = ?", [file])
    end

    def like_meme(file)
      DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [file])
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    redirect "/random"
  end

  get "/random" do
    @meme = DB.execute("SELECT * FROM meme_stats ORDER BY RANDOM() LIMIT 1").first
    @image_src = @meme["url"] if @meme
    erb :random
  end
  
  # Serve random/prev/next meme as JSON for JS navigation
  get "/random.json" do
    direction = params[:direction]
    current_url = params[:current_url]
  
    if current_url
      current_meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", [current_url]).first
      if current_meme
        case direction
        when "next"
          @meme = DB.execute("SELECT * FROM meme_stats WHERE id > ? ORDER BY id ASC LIMIT 1", [current_meme["id"]]).first
        when "prev"
          @meme = DB.execute("SELECT * FROM meme_stats WHERE id < ? ORDER BY id DESC LIMIT 1", [current_meme["id"]]).first
        end
      end
    end
  
    # fallback: random meme if no next/prev found
    @meme ||= DB.execute("SELECT * FROM meme_stats ORDER BY RANDOM() LIMIT 1").first
  
    content_type :json
    {
      title: @meme["title"],
      url: @meme["url"],
      subreddit: @meme["subreddit"],
      likes: @meme["likes"]
    }.to_json
  end

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
  
    # Fetch existing meme stats
    meme = DB.execute("SELECT * FROM meme_stats WHERE url = ?", [url]).first
  
    if meme
      liked = session[:liked_memes].include?(url)
  
      if liked
        # Unlike: decrease likes, remove from session
        new_likes = [meme["likes"] - 1, 0].max
        DB.execute("UPDATE meme_stats SET likes = ? WHERE url = ?", [new_likes, url])
        session[:liked_memes].delete(url)
        liked = false
      else
        # Like: increase likes, add to session
        new_likes = meme["likes"] + 1
        DB.execute("UPDATE meme_stats SET likes = ? WHERE url = ?", [new_likes, url])
        session[:liked_memes] << url
        liked = true
      end
  
      { liked: liked, likes: new_likes }.to_json
    else
      status 404
      { error: "Meme not found" }.to_json
    end
  end
  
  get "/metrics" do
    # -----------------------
    # Safe caches and defaults
    # -----------------------
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
  
    begin
      # -----------------------
      # Last batch fetched
      # -----------------------
      @last_batch = MEME_CACHE[:fetched_at] || Time.now
  
      # -----------------------
      # Initialize metrics
      # -----------------------
      @total_memes = 0
      @total_likes = 0
      @total_views = 0
      @memes_with_no_likes = 0
      @memes_with_no_views = 0
      @redis_views = 0
      @redis_likes = 0
      @redis_no_views = 0
      @redis_no_likes = 0
      @avg_likes = 0
      @avg_views = 0
      @avg_request_time_ms = 0
      @total_requests = 0
      @cache_hits = 0
      @cache_misses = 0
      @api_calls = 0
      @tier1_calls = 0
      @tier2_calls = 0
      @tier3_calls = 0
      @top_memes = []
      @top_subreddits = []
  
      # -----------------------
      # Aggregate stats from DB
      # -----------------------
      if defined?(DB)
        begin
          db_count      = DB.execute("SELECT COUNT(*) AS count FROM meme_stats").first
          db_sum_likes  = DB.execute("SELECT SUM(likes) AS sum FROM meme_stats").first
          db_sum_views  = DB.execute("SELECT SUM(views) AS sum FROM meme_stats").first
          no_likes      = DB.execute("SELECT COUNT(*) AS count FROM meme_stats WHERE likes = 0").first
          no_views      = DB.execute("SELECT COUNT(*) AS count FROM meme_stats WHERE views = 0").first
  
          @total_memes = db_count&.dig("count").to_i
          @total_likes = db_sum_likes&.dig("sum").to_i
          @total_views = db_sum_views&.dig("sum").to_i
          @memes_with_no_likes = no_likes&.dig("count").to_i
          @memes_with_no_views = no_views&.dig("count").to_i
  
          @avg_likes = @total_memes > 0 ? (@total_likes.to_f / @total_memes).round(2) : 0
          @avg_views = @total_memes > 0 ? (@total_views.to_f / @total_memes).round(2) : 0
        rescue => e
          puts "Warning: Could not aggregate DB stats - #{e.class}: #{e.message}"
        end
      else
        puts "Warning: DB not defined"
      end
  
      # -----------------------
      # Redis counters (safe)
      # -----------------------
      if REDIS
        begin
          @redis_views    = REDIS.get("total_views")&.to_i || 0
          @redis_likes    = REDIS.get("total_likes")&.to_i || 0
          @redis_no_views = REDIS.get("memes_no_views")&.to_i || 0
          @redis_no_likes = REDIS.get("memes_no_likes")&.to_i || 0
        rescue => e
          puts "Warning: Redis read failed - #{e.class}: #{e.message}"
        end
      end
  
      # -----------------------
      # App metrics
      # -----------------------
      @avg_request_time_ms = METRICS[:avg_request_time_ms] || 0
      @total_requests      = METRICS[:total_requests] || 0
      @cache_hits          = METRICS[:cache_hits] || 0
      @cache_misses        = METRICS[:cache_misses] || 0
      @api_calls           = METRICS[:api_calls] || 0
      @tier1_calls         = METRICS[:tier1_calls] || 0
      @tier2_calls         = METRICS[:tier2_calls] || 0
      @tier3_calls         = METRICS[:tier3_calls] || 0
  
      # -----------------------
      # Top memes & subreddits
      # -----------------------
      if defined?(DB)
        begin
          @top_memes = DB.execute("
            SELECT url, title, subreddit, likes, views
            FROM meme_stats
            ORDER BY likes DESC, views DESC
            LIMIT 10
          ")
  
          @top_subreddits = DB.execute("
            SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
            FROM meme_stats
            GROUP BY subreddit
            ORDER BY total_likes DESC
            LIMIT 10
          ")
        rescue => e
          puts "Warning: Could not fetch top memes/subreddits - #{e.class}: #{e.message}"
        end
      end
  
      # -----------------------
      # Render metrics page
      # -----------------------
      erb :metrics
  
    rescue => e
      puts "Error in /metrics: #{e.class} - #{e.message}"
      puts e.backtrace
      halt 500, "Internal Server Error"
    end
  end  
  

  # -----------------------
  # Server Start
  # -----------------------
  if $PROGRAM_NAME == __FILE__
    MemeExplorer.run! port: 4567, bind: "0.0.0.0"
  end
end
