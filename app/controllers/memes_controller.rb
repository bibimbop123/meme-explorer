class MemesController < ApplicationController
  def index
  end

  def show
  end

  def random
    genre = params[:genre] || 'all'
    
    # Fetch random meme based on genre
    meme = if genre == 'all'
      Meme.order('RANDOM()').first
    else
      Meme.where(category: genre).order('RANDOM()').first
    end

    # Handle JSON API requests (AJAX)
    respond_to do |format|
      format.json do
        if meme
          render json: {
            url: meme.image_url,
            title: meme.title,
            subreddit: meme.category,
            likes: meme.view_count || 0,
            source_url: meme.source_url
          }, status: 200
        else
          render json: { error: 'No memes available' }, status: 404
        end
      end
      
      # Handle HTML requests (page load)
      format.html do
        if meme
          @meme = meme
          @image_src = meme.image_url
          @likes = meme.view_count || 0
          @reddit_path = meme.source_url
          @media_type = determine_media_type(meme.image_url)
        end
      end
    end
  end

  private

  def determine_media_type(url)
    ext = File.extname(url&.downcase).to_s
    if ext.match?(/\.(mp4|webm)$/)
      'video'
    else
      'image'
    end
  end

  def search
  end

  def trending
  end
end
