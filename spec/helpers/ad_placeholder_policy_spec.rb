require_relative '../spec_helper'

RSpec.describe 'Demo ad placement policy' do
  around do |example|
    previous = ENV.to_h.slice('AD_PLACEHOLDER_PREVIEW', 'RACK_ENV', 'DISABLE_ADS')
    example.run
  ensure
    %w[AD_PLACEHOLDER_PREVIEW RACK_ENV DISABLE_ADS].each do |key|
      previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key)
    end
  end

  it 'renders no demo slots by default on Random' do
    ENV.delete('AD_PLACEHOLDER_PREVIEW')
    get '/random'
    expect(last_response.status).to eq(200)
    expect(last_response.body).not_to include('Ad Placeholder', 'class="ad-anchor-bottom"', 'data-position="left"', 'data-position="right"')
  end

  it 'supports explicit test preview but never production placeholders' do
    helper = Object.new.extend(AdHelpers)
    allow(helper).to receive(:should_show_ads?).and_return(true)
    ENV['AD_PLACEHOLDER_PREVIEW'] = 'true'
    ENV['RACK_ENV'] = 'test'
    expect(helper.render_ad_unit).to include('Ad Placeholder')
    expect(helper.render_anchor_ad).to include('ad-anchor-bottom')
    ENV['RACK_ENV'] = 'production'
    expect(helper.render_ad_unit).to eq('')
    expect(helper.render_anchor_ad).to eq('')
  end

  it 'renders a clean static sponsor card only when SPONSOR_NAME and a valid https SPONSOR_URL are set' do
    helper = Object.new.extend(AdHelpers)
    allow(helper).to receive(:should_show_ads?).and_return(true)
    expect(helper.render_sponsor_slot).to eq('')
    ENV['SPONSOR_NAME'] = 'Acme Games'
    ENV['SPONSOR_URL'] = 'https://acme.example/play'
    ENV['SPONSOR_TAGLINE'] = 'Quick browser fun'
    html = helper.render_sponsor_slot
    expect(html).to include('Supported by', 'Acme Games', 'https://acme.example/play', 'Quick browser fun')
    ENV['SPONSOR_URL'] = 'javascript:alert(1)'
    expect(helper.render_sponsor_slot).to eq('')
  ensure
    %w[SPONSOR_NAME SPONSOR_URL SPONSOR_TAGLINE].each { |k| ENV.delete(k) }
  end
end