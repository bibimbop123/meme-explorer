# app.rb
require "sinatra/base"
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

require_relative "./db/setup" # defines DB and REDIS

# -----------------------
# Redis setup
# -----------------------
REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
REDIS = Redis.new(url: REDIS_URL)

# -----------------------
# Rack::Attack
# -----------------------
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL)
class Rack::Attack
  safelist("allow-localhost") { |req| ["127.0.0.1", "::1"].include?(req.ip) }
  throttle("req/ip", limit: 60, period: 60) { |req| req.ip unless req.path.start_with?("/assets") }

  self.throttled_responder = lambda do |env|
    [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests. Please slow down." }.to_json]]
  end
end

class MemeExplorer < Sinatra::Base
  configure do
    set :server, :puma
    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) }

    MEMES = YAML.load_file("data/memes.yml")
    METRICS = {
      cache_hits: 0,
      cache_misses: 0,
      api_calls: 0,
      total_requests: 0,
      avg_request_time_ms: 0.0,
      tier1_calls: 0,
      tier2_calls: 0,
      tier3_calls: 0
    }

    Thread.new do
      loop do
        REDIS.setex("memes:latest", 180, MEMES.to_json)
        sleep 180
      end
    end
  end

  use Rack::Attack

  before do
    @start_time = Time.now
    @seen_memes = request.cookies["seen_memes"] ? JSON.parse(request.cookies["seen_memes"]) : []
    session[:liked_memes] ||= []
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
      expires: Time.now + 60*60*24*30,
      httponly: true
    )
  end

  helpers do
    # -----------------------
    # Memes caching
    # -----------------------
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
      get_cached_memes.values.flatten.map do |m|
        m["subreddit"] ||= "local"
        m
      end
    end

    # -----------------------
    # Weighted sampling
    # -----------------------
    def weighted_sample(memes)
      memes.flat_map { |m| key = m["file"] || m["url"]; session[:liked_memes].include?(key) ? [m]*3 : [m] }.sample
    end

    # -----------------------
    # API fetching
    # -----------------------
    MEME_CACHE ||= { memes: [], fetched_at: Time.at(0) }
    POPULAR_SUBREDDITS ||= %w[
      funny memes dankmemes wholesomememes PrequelMemes AdviceAnimals meme me_irl meirl terriblefacebookmemes
      ComedyCemetery holdmybeer Whatcouldgowrong facepalm blunderyears therewasanattempt instant_regret
      Animemes HistoryMemes madlads surrealmemes softwaregore CrappyDesign titlegore PublicFreakout Unexpected
      BreadStapledToTrees nocontextpics perfectTiming ContagiousLaughter wholesome AnimalsBeingDerps
      UnexpectedlyWholesome cringepics OldPeopleFacebook ProgrammerHumor techsupportgore CodeReviewHumor
      EngineeringMemes sbubby ihadastroke ZillowGoneWild OldSchoolCoolMemes Catstandingup
    ].freeze

    def get_memes_from_reddit(batch_size = 20)
      memes = []
      POPULAR_SUBREDDITS.sample(8).each do |subreddit|
        2.times do
          url = URI("https://meme-api.com/gimme/#{subreddit}/#{batch_size}")
          begin
            response = Net::HTTP.get(url)
            data = JSON.parse(response)
            new_memes = data["memes"] || []
            memes.concat(new_memes.map { |m| { "title" => m["title"], "url" => m["url"], "postLink" => m["postLink"], "subreddit" => m["subreddit"] } })
          rescue => e
            puts "API error for #{subreddit}: #{e.message}"
            next
          end
        end
      end
      memes.uniq { |m| m["url"] }
    end

    def fetch_fresh_memes(batch_size = 20)
      if Time.now - MEME_CACHE[:fetched_at] > 120
        MEME_CACHE[:memes] = get_memes_from_reddit(batch_size)
        MEME_CACHE[:fetched_at] = Time.now
      end
      MEME_CACHE[:memes]
    end

    # -----------------------
    # Tiered random algorithms
    # -----------------------
    def tier1_random
      METRICS[:tier1_calls] += 1
      flatten_memes.sample
    end

    def tier2_random
      METRICS[:tier2_calls] += 1
      weighted_sample(flatten_memes)
    end

    def tier3_random(top_n_subs = 5)
      METRICS[:tier3_calls] += 1
      subreddits = get_cached_memes.keys.sample(top_n_subs)
      local_memes = subreddits.flat_map { |sub| get_cached_memes[sub] || [] }
      api_memes = fetch_fresh_memes(10)
      all_candidates = (local_memes + api_memes).uniq { |m| m["url"] || m["file"] }
      unseen = all_candidates.reject { |m| @seen_memes.include?(m["url"] || m["file"]) }
      pool = unseen.any? ? unseen : all_candidates
      weighted = pool.flat_map do |m|
        key = m["url"] || m["file"]
        session[:liked_memes].include?(key) ? [m]*3 : [m]
      end
      weighted.sample
    end

    # -----------------------
    # Database tracking
    # -----------------------
    def increment_view(file, title:, subreddit:)
      DB.execute("INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, ?, ?, 0, 0)", [file, title, subreddit])
      DB.execute("UPDATE meme_stats SET views = views + 1 WHERE url = ?", [file])
      REDIS.incr("memes:views")
      REDIS.incr("memes:no_views") if DB.execute("SELECT views FROM meme_stats WHERE url = ?", [file]).first["views"] == 1
    end

    def like_meme(file)
      DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [file])
      REDIS.incr("memes:likes")
      REDIS.decr("memes:no_likes") if DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [file]).first["likes"] == 1
    end

    def fetch_top_trending(limit = 10)
      db_memes = DB.execute("SELECT url, title, subreddit, views, likes FROM meme_stats ORDER BY likes DESC, views DESC LIMIT ?", [limit])
      db_memes.map { |r| { url: r["url"], title: r["title"], subreddit: r["subreddit"], views: r["views"], likes: r["likes"] } }
    end
  end

  # -----------------------
  # Routes
  # -----------------------
  get "/" do
    redirect "/random"
  end

  get "/random" do
    direction = params[:direction]
    session[:meme_history] ||= []
    session[:meme_index] ||= -1
  
    if direction == "prev"
      # Go back one meme in history (if possible)
      if session[:meme_index] > 0
        session[:meme_index] -= 1
      end
      @meme = session[:meme_history][session[:meme_index]]
    else
      # Next meme (default behavior)
      @meme = tier3_random || { "title" => "No memes", "file" => "/images/placeholder.png", "subreddit" => "local" }
  
      # Store it in the session history
      session[:meme_history] << @meme
      session[:meme_index] = session[:meme_history].size - 1
  
      # Increment view count only for new memes
      increment_view(@meme["file"] || @meme["url"], title: @meme["title"], subreddit: @meme["subreddit"]) if @meme["file"]
    end
  
    @image_src = @meme["file"] || @meme["url"]
    @category_name = @meme["subreddit"]
  
    erb :random, layout: :layout
  end
  

  get "/random.json" do
    content_type :json
    direction = params[:direction]
    session[:meme_history] ||= []
    session[:meme_index] ||= -1
  
    if direction == "prev"
      if session[:meme_index] > 0
        session[:meme_index] -= 1
      end
      meme = session[:meme_history][session[:meme_index]]
    else
      meme = tier3_random || { "title" => "No memes", "file" => "/images/placeholder.png", "subreddit" => "local" }
      session[:meme_history] << meme
      session[:meme_index] = session[:meme_history].size - 1
      increment_view(meme["file"] || meme["url"], title: meme["title"], subreddit: meme["subreddit"]) if meme["file"]
    end
  
    {
      title: meme["title"],
      subreddit: meme["subreddit"],
      url: meme["file"] || meme["url"],
      likes: DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [meme["file"] || meme["url"]]).first&.fetch("likes", 0) || 0
    }.to_json
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

  get "/trending" do
    raw_memes = DB.execute(<<-SQL)
      SELECT url, title, subreddit, views, likes,
             (likes * 2 + views) / (JULIANDAY('now') - JULIANDAY(updated_at) + 1) AS trending_score
      FROM meme_stats
      ORDER BY trending_score DESC
      LIMIT 20;
    SQL
  
    # Convert frozen SQLite rows into a mutable array of hashes
    @memes = raw_memes.map do |row|
      {
        url: row["url"],
        title: row["title"],
        subreddit: row["subreddit"],
        views: row["views"],
        likes: row["likes"],
        trending_score: row["trending_score"]
      }
    end
  
    erb :trending, layout: :layout
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
    file = params["url"]
    halt 400, { error: "Missing URL" }.to_json unless file
    session[:liked_memes] ||= []
  
    liked = if session[:liked_memes].include?(file)
              session[:liked_memes].delete(file)
              DB.execute("UPDATE meme_stats SET likes = likes - 1 WHERE url = ?", [file])
              false
            else
              session[:liked_memes] << file
              DB.execute("INSERT OR IGNORE INTO meme_stats (url, title, subreddit, views, likes) VALUES (?, 'Unknown', 'local', 0, 0)", [file])
              DB.execute("UPDATE meme_stats SET likes = likes + 1 WHERE url = ?", [file])
              true
            end
  
    likes = DB.execute("SELECT likes FROM meme_stats WHERE url = ?", [file]).first["likes"]
    { liked: liked, likes: likes, url: file }.to_json
  end
  
  
  get "/metrics" do
    # -----------------------
    # Aggregate stats
    # -----------------------
    last_batch = MEME_CACHE[:fetched_at] || Time.now

    total_memes  = DB.execute("SELECT COUNT(*) AS count FROM meme_stats").first["count"] || 0
    total_likes  = DB.execute("SELECT SUM(likes) AS sum FROM meme_stats").first["sum"] || 0
    total_views  = DB.execute("SELECT SUM(views) AS sum FROM meme_stats").first["sum"] || 0
    avg_likes    = total_memes > 0 ? (total_likes.to_f / total_memes).round(2) : 0
    avg_views    = total_memes > 0 ? (total_views.to_f / total_memes).round(2) : 0
    memes_with_no_likes = DB.execute("SELECT COUNT(*) AS count FROM meme_stats WHERE likes = 0").first["count"]
    memes_with_no_views = DB.execute("SELECT COUNT(*) AS count FROM meme_stats WHERE views = 0").first["count"]
  
    # -----------------------
    # Top 10 memes
    # -----------------------
    top_memes = DB.execute("SELECT url, title, subreddit, likes, views FROM meme_stats ORDER BY likes DESC, views DESC LIMIT 10")
  
    # -----------------------
    # Top 10 subreddits by likes
    # -----------------------
    top_subreddits = DB.execute("
      SELECT subreddit, SUM(likes) AS total_likes, COUNT(*) AS count
      FROM meme_stats
      GROUP BY subreddit
      ORDER BY total_likes DESC
      LIMIT 10
    ")
  
    # -----------------------
    # Render ERB metrics page
    # -----------------------
    erb :metrics, locals: {
      total_memes: total_memes,
      total_likes: total_likes,
      total_views: total_views,
      avg_likes: avg_likes,
      avg_views: avg_views,
      memes_with_no_likes: memes_with_no_likes,
      memes_with_no_views: memes_with_no_views,
      top_memes: top_memes,
      top_subreddits: top_subreddits,
      last_batch: last_batch
    }
    
  end
  
  run! if app_file == $0
end
