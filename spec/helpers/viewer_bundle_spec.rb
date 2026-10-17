require_relative '../spec_helper'

RSpec.describe 'Viewer bundle cache identity' do
  it 'versions the viewer stylesheet from its actual bytes' do
    expected = Digest::SHA256.file(File.expand_path('../../public/css/viewer-controls.css', __dir__)).hexdigest[0, 16]
    helper = Object.new.extend(AppHelpers)
    expect(helper.viewer_stylesheet_path).to eq("/css/viewer-controls.css?v=#{expected}")
    get '/login'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("href=\"/css/viewer-controls.css?v=#{expected}\"")
  end

  it 'versions the browser asset URL from the actual built bundle' do
    expected = Digest::SHA256.file(File.expand_path('../../public/dist/bundle.js', __dir__)).hexdigest[0, 16]
    helper = Object.new.extend(AppHelpers)
    expect(helper.viewer_bundle_path).to eq("/dist/bundle.js?v=#{expected}")
    get '/login'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("src=\"/dist/bundle.js?v=#{expected}\"")
  end
end