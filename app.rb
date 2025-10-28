require 'sinatra/base'
require 'yaml'
require 'uri'
require 'net/http'
require 'json'

class MemeExplorer < Sinatra::Base
  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  MEMES = YAML.load_file("./data/memes.yml").transform_keys(&:to_s)
  VIEW_COUNTS ||= Hash.new(0)
  enable :sessions

  # Expanded subreddit pool for more variety
  ALL_SUBREDDITS = %w[
    dankmemes memes wholesomeMemes me_irl ProgrammerHumor
    funny adviceanimals comedyheaven historymemes wholesomememes
    starterpacks prequelmemes okbuddyretard memeEconomy
    surrealmemes pewdiepieSubmissions ITMemes TerribleFacebookMemes
    gamingmemes PoliticalHumor antiwork nextfuckinglevel
    WhitePeopleTwitter BlackPeopleTwitter teenagers
    cats memes_of_the_dank dogmemes wholesomeanimemes
  ].freeze

  POPULAR_SUBREDDITS = ALL_SUBREDDITS.sample(8)
  MEME_CACHE = { memes: [], fetched_at: Time.at(0) }

  # =========================
  # Cookie Setup for Seen Memes
  # =========================
  before do
    seen_cookie = request.cookies["seen_memes"]
    @seen_memes = seen_cookie ? JSON.parse(seen_cookie) : []
  end

  after do
    response.set_cookie("seen_memes", {
      value: @seen_memes.to_json,
      path: "/",
      expires: Time.now + 60*60*24*30, # 30 days
      httponly: true
    })
  end

  # =========================
  # Routes
  # =========================

  get '/' do
    erb :index
  end

  get '/category/:name' do
    @category_name = params[:name]
    @memes = MEMES[@category_name]
    halt 404, "Category not found" unless @memes
    erb :category
  end

  get '/random' do
    memes = random_meme_pool.reject { |m| @seen_memes.include?(m["url"] || m["file"]) }

    if memes.empty?
      category, local_memes = MEMES.to_a.sample
      memes = local_memes
      @category_name = category
    else
      @category_name = "Reddit & Local Memes"
    end

    @meme = memes.sample
    @image_src = @meme["url"] || @meme["file"]

    seen_key = @meme["url"] || @meme["file"]
    if seen_key
      @seen_memes << seen_key
      @seen_memes = @seen_memes.last(100) # keep only last 100 seen
    end

    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]

    erb :meme
  end

  get '/search' do
    query = params[:q].to_s.downcase
    @results = MEMES.flat_map do |category, memes|
      memes.select { |m| m["title"].downcase.include?(query) }
           .map { |m| [category, m] }
    end
    erb :search_results
  end

  get '/category/:category/meme/:title' do
    @category_name = params[:category]
    category_memes = MEMES[@category_name]
    halt 404, "Category not found" unless category_memes

    title = URI.decode_www_form_component(params[:title])
    @meme = category_memes.find { |m| m["title"] == title }
    halt 404, "Meme not found" unless @meme

    @image_src = @meme["url"] || @meme["file"]
    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]

    erb :meme
  end

  get '/api_memes' do
    @api_memes = fetch_api_memes
    erb :api_memes
  end

  post '/like' do
    content_type :json
    begin
      meme_url = params[:url]
      session[:liked_memes] ||= []

      if session[:liked_memes].include?(meme_url)
        session[:liked_memes].delete(meme_url)
        liked = false
      else
        session[:liked_memes] << meme_url
        liked = true
      end

      { liked: liked }.to_json
    rescue => e
      status 500
      { error: e.message }.to_json
    end
  end

  # =========================
  # Helpers
  # =========================

  def random_meme_pool
    api_memes = fetch_fresh_memes(20)
    global_randoms = fetch_global_randoms(20)
    local_memes = MEMES.values.flatten.sample(10)
    (api_memes + global_randoms + local_memes).shuffle.uniq { |m| m["url"] || m["file"] }
  end

  # Fetch memes from selected subreddits with multiple calls per subreddit
  def fetch_fresh_memes(batch_size = 20)
    if Time.now - MEME_CACHE[:fetched_at] > 120 # refresh every 2 min
      MEME_CACHE[:memes] = get_memes_from_reddit(batch_size)
      MEME_CACHE[:fetched_at] = Time.now
    end
    MEME_CACHE[:memes]
  end

  def get_memes_from_reddit(batch_size = 20)
    memes = []

    POPULAR_SUBREDDITS.sample(8).each do |subreddit|
      2.times do
        url = URI("https://meme-api.com/gimme/#{subreddit}/#{batch_size}")
        begin
          response = Net::HTTP.get(url)
          data = JSON.parse(response)
          new_memes = data["memes"] || []
          memes.concat(new_memes.map do |m|
            {
              "title" => m["title"],
              "url" => m["url"],
              "postLink" => m["postLink"],
              "subreddit" => m["subreddit"]
            }
          end)
        rescue => e
          puts "API error for #{subreddit}: #{e.message}"
          next
        end
      end
    end

    memes.uniq { |m| m["url"] }
  end

  # Fetch global random memes to increase variety
  def fetch_global_randoms(count = 20)
    url = URI("https://meme-api.com/gimme/#{count}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    (data["memes"] || [data]).compact.map do |m|
      { "title" => m["title"], "url" => m["url"], "postLink" => m["postLink"], "subreddit" => m["subreddit"] }
    end
  rescue
    []
  end

  def fetch_api_memes(count = 18)
    url = URI("https://meme-api.com/gimme/#{count}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    memes = if data["memes"]
              data["memes"]
            elsif data["url"]
              [data]
            else
              []
            end

    memes.map do |m|
      {
        "title" => m["title"],
        "url" => m["url"],
        "postLink" => m["postLink"],
        "subreddit" => m["subreddit"]
      }
    end
  rescue StandardError => e
    puts "API Error: #{e.message}"
    []
  end

  run! if app_file == $0
end
