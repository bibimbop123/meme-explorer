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

  get '/' do
    erb :index
  end

  get '/category/:name' do
    @category_name = params[:name]         # string keys
    @memes = MEMES[@category_name]
    halt 404, "Category not found" unless @memes
    erb :category
  end

  enable :sessions

  get '/random' do
    session[:seen_memes] ||= []
  
    memes = fetch_fresh_memes.reject { |m| session[:seen_memes].include?(m["url"]) }
  
    if memes.empty?
      # fallback to local memes
      category, local_memes = MEMES.to_a.sample
      memes = local_memes
      @category_name = category
    else
      @category_name = "Reddit Memes"
    end
  
    @meme = memes.sample
    session[:seen_memes] << @meme["url"] if @meme["url"]
    
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
    @category_name = params[:category]     # string keys
    category_memes = MEMES[@category_name]
    halt 404, "Category not found" unless category_memes

    title = URI.decode_www_form_component(params[:title])
    @meme = category_memes.find { |m| m["title"] == title }
    halt 404, "Meme not found" unless @meme

    VIEW_COUNTS[@meme["title"]] += 1
    @views = VIEW_COUNTS[@meme["title"]]
    erb :meme
  end

  get '/api_memes' do
    @api_memes = fetch_api_memes
    erb :api_memes
  end

  POPULAR_SUBREDDITS = %w[dankmemes memes wholesomeMemes me_irl ProgrammerHumor].freeze

  def fetch_fresh_memes
    subreddit = POPULAR_SUBREDDITS.sample
    url = URI("https://meme-api.com/gimme/#{subreddit}/10")
    
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    
    # Meme-API can return "memes" array or fallback
    memes = data["memes"] || []
    
    # normalize meme data to match local structure
    memes.map do |m|
      {
        "title" => m["title"],
        "url" => m["url"],
        "postLink" => m["postLink"],
        "subreddit" => m["subreddit"]
      }
    end
  rescue StandardError => e
    puts "API Error in fetch_fresh_memes: #{e.message}"
    []  # return empty array instead of crashing
  end
  

  def fetch_api_memes(count = 18)
    url = URI("https://meme-api.com/gimme/#{count}")  # get multiple memes
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
  
    # Meme-API can return a single meme or multiple memes depending on the count
    memes = if data["memes"] # multiple memes
              data["memes"]
            elsif data["url"] # single meme
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
  
  # When user clicks "like"
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
  

  def weighted_subreddit
    liked = session[:liked_memes] || []
    liked_subs = liked.map do |url|
      # Extract subreddit info from meme data if available
      # For now, just random weight if liked
      POPULAR_SUBREDDITS.sample
    end
  
    weights = POPULAR_SUBREDDITS.map do |sub|
      [sub, liked_subs.count(sub) + 1]
    end
  
    weights.max_by { |_, w| rand ** (1.0 / w) }.first
  end
  
  

  

  run! if app_file == $0
end
