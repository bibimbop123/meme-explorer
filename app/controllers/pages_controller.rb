class PagesController < ApplicationController
  def home
    @memes = Meme.order(created_at: :desc).limit(12)
  end
end
