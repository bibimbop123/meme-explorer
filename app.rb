
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
require "ostruct"

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
  POPULAR_SUBREDDITS = YAML.load_file("data/subreddits.yml")["popular"]
  ALL_POPULAR_SUBS = POPULAR_SUBREDDITS.sample(50)
  MEME_CACHE = { memes: [], last_refresh: nil }
  MEMES = YAML.load_file("data/memes.yml") rescue []
  METRICS = Hash.new(0).merge(avg_request_time_ms: 0.0)

  # -----------------------
  # Configuration
  # -----------------------
  configure do
    set :server, :puma
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) }
  end

  # Background thread to populate cache with Reddit memes
  Thread.new do
    loop do
      begin
        # Call class method to fetch Reddit memes
        meme_pool = MemeExplorer.fetch_reddit_memes_static(POPULAR_SUBREDDITS, 20)
        puts "Fetched #{meme_pool.size} memes from Reddit"
        
        # Validate memes
        validated = meme_pool.select do |m|
          m["url"] && m["url"].match?(/^https?:\/\//)
        end
        
        puts "Validated #{validated.size} memes with working URLs"
        MEME_CACHE[:memes] = validated.shuffle
        MEME_CACHE[:last_refresh] = Time.now
      rescue => e
        puts "Cache refresh error: #{e.class} - #{e.message}"
        puts e.backtrace[0..5]
      end
      sleep 120
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
  # Static Methods (for background thread)
  # -----------------------
  def self.fetch_reddit_memes_static(subreddits = nil, limit = 15)
    # Reddit API requests are heavily blocked - return empty and rely on fallback
    puts "Reddit API access blocked - using local memes only"
    []
  end

  def self.extract_image_url_static(post_data)
    if post_data["url"]&.match?(/^https:\/\/i\.redd\.it\//)
      return post_data["url"]
    end

    if post_data["url"]&.match?(/^https:\/\/(i\.)?imgur\.com\//)
      return post_data["url"]
    end

    if post_data["preview"]&.dig("images", 0, "source", "url")
      url = post_data["preview"]["images"][0]["source"]["url"]
      return url.gsub("&amp;", "&") if url
    end

    nil
  end

  # -----------------------
  # Helpers
  # -----------------------
  helpers do
    # Safely get meme image
    def meme_image_src(m)
      return "/images/funny1.jpeg" unless m.is_a?(Hash)
      m["file"].to_s.strip != "" ? m["file"] : (m["url"].to_s.strip != "" ? m["url"] : "/images/funny1.jpeg")
    end

    # Fallback meme
    def fallback_meme
      { "title" => "No memes available", "file" => "/images/funny1.jpeg", "subreddit" => "local" }
    end

    # Ensure subreddit string
    def sanitize_subreddit(sub)
      return "local" if sub.nil? || sub.strip.empty?
      sub.downcase
    end

    # Navigate memes safely
    def navigate_meme(direction: "next")
      memes = random_memes_pool
      return nil if memes.empty?

      session[:meme_history] ||= []
      last_meme_url = session[:meme_history].last

      # Get a random meme that's different from the last one shown
      new_meme = nil
      attempts = 0
      max_attempts = [memes.size, 20].min
      
      while attempts < max_attempts
        candidate = memes.sample
        candidate_id = candidate["url"] || candidate["file"]
        
        if candidate_id != last_meme_url && is_valid_meme?(candidate)
          new_meme = candidate
          break
        end
        attempts += 1
      end

      return nil unless new_meme

      meme_identifier = new_meme["url"] || new_meme["file"]
      session[:meme_history] << meme_identifier
      session[:meme_history] = session[:meme_history].last(30)

      new_meme
    end

    # Validate meme before display
    def is_valid_meme?(meme)
      return false unless meme.is_a?(Hash)
      
      if meme["file"]
        File.exist?(File.join("public", meme["file"]))
      elsif meme["url"]
        meme["url"].match?(/^https?:\/\//)
      else
        false
      end
    end

    # Get memes from cache or MEMES
    def get_cached_memes
      cached = REDIS&.get("memes:latest")
      memes = cached ? JSON.parse(cached) : MEME_CACHE[:memes] ||= MEMES

      memes.reject! do |m|
        file_missing = m["file"] && !File.exist?(File.join(settings.public_folder, m["file"]))
        url_invalid  = m["url"] && !m["url"].match?(/^https?:\/\//)
        file_missing || url_invalid
      end

      REDIS&.setex("memes:latest", 300, memes.to_json) rescue nil
      MEME_CACHE[:memes] = memes
    rescue
      MEME_CACHE[:memes] ||= MEMES
    end

    # Fetch memes from popular subreddits with working image links
    def fetch_reddit_memes(subreddits = POPULAR_SUBREDDITS, limit = 15)
      memes = []
      subreddits = subreddits.sample(5) if subreddits.size > 5

      subreddits.each do |subreddit|
        begin
          url = "https://www.reddit.com/r/#{subreddit}/top.json?t=week&limit=#{limit}"
          uri = URI(url)
          
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri.request_uri)
            request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            request["Accept"] = "application/json"
            
            response = http.request(request)
            
            next unless response.code == "200"
            
            body = response.body
            data = JSON.parse(body)

            data["data"]["children"].each do |post|
              post_data = post["data"]
              next if post_data["is_video"] || post_data["is_self"] || !post_data["url"]

              # Extract working image URLs from Reddit posts
              image_url = extract_image_url(post_data)
              next unless image_url && image_url.match?(/^https?:\/\//)

              meme = {
                "title" => post_data["title"],
                "url" => image_url,
                "subreddit" => post_data["subreddit"],
                "likes" => post_data["ups"] || 0
              }
              memes << meme
            end
          end
          sleep 1  # Be respectful to Reddit
        rescue JSON::ParserError => e
          # Silently skip on JSON parse errors
          next
        rescue => e
          # Silently skip on other errors
          next
        end
      end

      memes
    end

    # Extract direct image URL from Reddit post data
    def extract_image_url(post_data)
      # Direct i.redd.it links (native Reddit images)
      if post_data["url"]&.match?(/^https:\/\/i\.redd\.it\//)
        return post_data["url"]
      end

      # imgur direct links
      if post_data["url"]&.match?(/^https:\/\/(i\.)?imgur\.com\//)
        return post_data["url"]
      end

      # Check media metadata for preview image
      if post_data["preview"]&.dig("images", 0, "source", "url")
        url = post_data["preview"]["images"][0]["source"]["url"]
        return url.gsub("&amp;", "&") if url
      end

      nil
    end

    # Get meme pool from cache or build fresh - prioritizes API memes
    def random_memes_pool
      # Use cached pool if fresh (less than 2 minutes old)
      if MEME_CACHE[:memes].is_a?(Array) && !MEME_CACHE[:memes].empty? &&
         MEME_CACHE[:last_refresh] && (Time.now - MEME_CACHE[:last_refresh]) < 120
        return MEME_CACHE[:memes]
      end

      # Fetch fresh API memes first (primary source)
      api_memes = fetch_reddit_memes(POPULAR_SUBREDDITS, 20) rescue []
      
      # Only add local memes as fallback
      local_memes = if api_memes.empty?
                      MEMES.is_a?(Array) ? MEMES : MEMES.values.flatten
                    else
                      []
                    end

      # Preferring API memes heavily
      pool = api_memes + local_memes
      pool = pool.uniq { |m| m["url"] || m["file"] }

      # Strict validation - only include memes with working images
      validated = pool.select { |m| is_valid_meme?(m) }

      MEME_CACHE[:memes] = validated.shuffle
      MEME_CACHE[:last_refresh] = Time.now

      validated.empty? ? [] : validated
    end

    # Get likes safely
    def get_meme_likes(url)
      return 0 unless url
      likes = REDIS&.get("meme:likes:#{url}")&.to_i
      return likes if likes

      row = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first
      likes = row ? row["likes"].to_i : 0
      REDIS&.set("meme:likes:#{url}", likes)
      likes
    end

    # Toggle like for meme (only count once per session)
    def toggle_like(url, liked_now, session)
      return 0 unless url
      
      session[:meme_like_counts] ||= {}
      was_liked_before = session[:meme_like_counts][url] || false
      
      # Only update DB on first like/unlike transition
      if liked_now && !was_liked_before
        # First time liking in this session
        DB.execute("INSERT OR IGNORE INTO meme_stats (url, likes) VALUES (?, 0)", [url])
        DB.execute("UPDATE meme_stats SET likes = likes + 1, updated_at = CURRENT_TIMESTAMP WHERE url = ?", [url])
        session[:meme_like_counts][url] = true
      elsif !liked_now && was_liked_before
        # Unliking after having liked in this session
        DB.execute("UPDATE meme_stats SET likes = likes - 1, updated_at = CURRENT_TIMESTAMP WHERE url = ? AND likes > 0", [url])
        session[:meme_like_counts][url] = false
      end

      likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", url).first&.dig("likes").to_i
      REDIS&.set("meme:likes:#{url}", likes)
      likes
    end

    # Flatten memes from YAML structure
    def flatten_memes
      return [] unless MEMES.is_a?(Hash)
      MEMES.values.flatten.compact
    end

    # Safely execute DB queries
    def safe_db_exec(query, params = [])
      return nil unless defined?(DB) && DB
      DB.execute(query, params)
    rescue => e
      puts "DB Error: #{e.message}"
      nil
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    @meme = navigate_meme(direction: "next")
    @image_src = meme_image_src(@meme)
    erb :random
  end

  get "/random" do
    @meme = navigate_meme(direction: "random")
    @image_src = meme_image_src(@meme)
    erb :random
  end

  get "/random.json" do
    @meme = navigate_meme(direction: "random")
    halt 404, { error: "No memes found" }.to_json if @meme.nil?

    content_type :json
    {
      title: @meme["title"],
      subreddit: @meme["subreddit"],
      file: @meme["file"],
      url: @meme["url"],
      likes: get_meme_likes(@meme["url"] || @meme["file"])
    }.to_json
  end
  
  post "/like" do
    url = params[:url]
    halt 400, { error: "No URL provided" }.to_json unless url
  
    session[:liked_memes] ||= []
    session[:meme_like_counts] ||= {}
  
    # Toggle user's local like state
    liked_now = if session[:liked_memes].include?(url)
                  session[:liked_memes].delete(url)
                  false
                else
                  session[:liked_memes] << url
                  true
                end
  
    # Only count like once per session globally
    likes = toggle_like(url, liked_now, session)
  
    content_type :json
    { liked: liked_now, likes: likes }.to_json
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
  before "/category/*" do
    # Define default categories if not loaded
    @categories = {
      funny: ["funny", "memes"],
      wholesome: ["wholesome", "aww"],
      dank: ["dank", "dankmemes"],
      selfcare: ["selfcare", "wellness"]
    }
  end
  
  get "/category/:name" do
    category_name = params[:name].to_sym
    subreddits = @categories[category_name]
    halt 404, { error: "Category not found" }.to_json unless subreddits && !subreddits.empty?
  
    # Filter valid memes
    local_memes = MEMES.is_a?(Hash) ? MEMES[category_name.to_s] || [] : []
    api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
  
    @memes = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
  
    # Use fallback only if empty
    @memes = [fallback_meme.merge("subreddit" => category_name.to_s)] if @memes.empty?
  
    if request.accept.include?("application/json")
      content_type :json
      @memes.to_json
    else
      @category_name = category_name
      erb :category, layout: :layout
    end
  end
  
  get "/category/:name/meme/:title" do
    category_name = params[:name].to_sym
    subreddits = @categories[category_name] || []
  
    local_memes = MEMES.is_a?(Hash) ? MEMES[category_name.to_s] || [] : []
    api_memes = (fetch_fresh_memes(batch_size: 50) rescue []).select { |m| subreddits.include?(m["subreddit"]) }
  
    combined = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
  
    requested_title = URI.decode_www_form_component(params[:title])
    @meme = combined.find { |m| m["title"] == requested_title }
  
    # Fallback
    @meme ||= fallback_meme.merge("subreddit" => category_name.to_s)
    @image_src = meme_image_src(@meme)
  
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
