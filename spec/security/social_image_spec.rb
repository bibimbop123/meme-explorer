require_relative '../spec_helper'
require_relative '../../lib/security/media_url'

RSpec.describe 'Social image candidates' do
  it 'makes local raster paths absolute and preserves encoded query strings' do
    expect(MediaUrl.social_image('/images/meme.PNG?size=2&format=png', origin: 'https://memes.example')).to eq('https://memes.example/images/meme.PNG?size=2&format=png')
    expect(MediaUrl.social_image('https://i.redd.it/meme.webp?width=900', origin: 'https://memes.example')).to eq('https://i.redd.it/meme.webp?width=900')
  end

  it 'fails closed for malformed, executable, credentialed and non-raster sources' do
    [nil, {}, '/images/%broken.jpg', 'javascript:alert(1)', '//evil.example/a.jpg',
     'https://user:password@evil.example/a.jpg', 'https://i.redd.it/a.svg',
     'https://v.redd.it/a.mp4', 'https://i.redd.it/no-extension?name=a.jpg'].each do |source|
      expect(MediaUrl.social_image(source, origin: 'https://memes.example')).to be_nil
    end
  end
end