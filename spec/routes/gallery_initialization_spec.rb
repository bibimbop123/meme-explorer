require_relative '../spec_helper'

RSpec.describe 'Initial gallery controller ownership' do
  it 'emits one initializer for a server-rendered gallery' do
    images = [
      { 'url' => 'https://i.redd.it/one.jpg', 'width' => 800, 'height' => 1200 },
      { 'url' => 'https://i.redd.it/two.jpg', 'width' => 800, 'height' => 1200 }
    ]
    meme = { 'url' => images.first['url'], 'title' => 'Gallery ownership', 'subreddit' => 'funny',
      'is_gallery' => true, 'gallery_images' => images }
    allow(MemePoolManager).to receive(:get_pool).and_return(success: true, memes: [meme], pool_size: 1)
    get '/random'
    expect(last_response.status).to eq(200)
    expect(last_response.body.scan("const galleries = document.querySelectorAll('.gallery-carousel')").length).to eq(1)
    expect(last_response.body).to include('gallery.dataset.carouselReady')
    expect(last_response.body).to include('Gallery ownership', 'data-recoverable-media')
  end
end