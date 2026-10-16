require_relative '../spec_helper'

RSpec.describe 'Utility endpoint ownership' do
  it 'serves the configured ads declaration as plain text' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GOOGLE_ADSENSE_CLIENT').and_return('ca-pub-3857156159165285')
    get '/ads.txt'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('text/plain')
    expect(last_response.body).to include(File.read(File.expand_path('../../ads.txt', __dir__)).strip)
  end

  it 'does not register a superseded utility random JSON handler' do
    app = double('registration target')
    context = Object.new
    expect(context).to receive(:content_type).with('text/plain')
    expect(app).to receive(:get).with('/ads.txt') do |&handler|
      expect(context.instance_exec(&handler)).to eq(File.read(File.expand_path('../../ads.txt', __dir__)))
    end
    Routes::UtilityRoutes.registered(app)
  end
end