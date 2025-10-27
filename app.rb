require 'sinatra/base'
require 'yaml'
require 'uri'
require 'net/http'

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

  get '/random' do
    if rand < 0.5
      category, memes = MEMES.to_a.sample
      @meme = memes.sample
      @category_name = category
    else
      api_meme = fetch_api_memes(1).first
      @meme = api_meme
      @category_name = "Reddit Memes"
    end
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
  

  def fetch_api_memes(count = 10)
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
  
  

  run! if app_file == $0
end
