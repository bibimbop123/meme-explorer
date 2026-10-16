require_relative '../spec_helper'
require_relative '../../lib/concerns/http_caching'

RSpec.describe HTTPCaching do
  let(:helper) { Object.new.extend(described_class) }
  let(:response_headers) { {} }
  let(:request_env) { {} }

  before do
    allow(helper).to receive(:headers).and_return(response_headers)
    allow(helper).to receive(:request).and_return(double(env: request_env))
    allow(helper).to receive(:halt) { |status| throw :halt, status }
  end

  it 'separates public and private page lifetimes' do
    helper.cache_page(duration: 60)
    expect(response_headers['Cache-Control']).to eq('public, max-age=60, s-maxage=120')
    helper.cache_page(duration: 60, type: :private)
    expect(response_headers['Cache-Control']).to eq('private, max-age=60')
    helper.cache_private(duration: 10)
    expect(response_headers['Cache-Control']).to eq('private, max-age=10')
  end

  it 'sets API variation and immutable-duration asset policy' do
    helper.cache_api_response(duration: 30)
    expect(response_headers).to include('Cache-Control' => 'public, max-age=30, s-maxage=30', 'Vary' => 'Accept, Accept-Encoding')
    helper.cache_asset
    expect(response_headers['Cache-Control']).to eq('public, max-age=31536000, s-maxage=31536000')
  end

  it 'explicitly prevents storage and supports revalidation directives' do
    helper.set_cache_headers(must_revalidate: true)
    expect(response_headers['Cache-Control']).to include('must-revalidate')
    helper.no_cache
    expect(response_headers).to include('Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0', 'Pragma' => 'no-cache', 'Expires' => '0')
  end

  it 'returns not modified for a matching content ETag' do
    helper.set_etag('content')
    request_env['HTTP_IF_NONE_MATCH'] = response_headers['ETag']
    expect(catch(:halt) { helper.set_etag('content') }).to eq(304)
  end

  it 'gives a nonmatching ETag precedence over a newer modification date' do
    request_env['HTTP_IF_NONE_MATCH'] = '"different"'
    request_env['HTTP_IF_MODIFIED_SINCE'] = Time.utc(2026, 10, 16).httpdate
    expect(helper).not_to receive(:halt)
    helper.cache_conditional('content', Time.utc(2026, 10, 15))
    expect(response_headers).to have_key('Last-Modified')
  end

  it 'compares modification dates at HTTP second precision' do
    time = Time.utc(2026, 10, 15) + 0.5
    request_env['HTTP_IF_MODIFIED_SINCE'] = time.httpdate
    expect(catch(:halt) { helper.set_last_modified(time) }).to eq(304)
  end

  it 'ignores invalid and older modification dates' do
    expect(helper).not_to receive(:halt)
    request_env['HTTP_IF_MODIFIED_SINCE'] = 'invalid'
    helper.set_last_modified(Time.utc(2026, 10, 15))
    request_env['HTTP_IF_MODIFIED_SINCE'] = Time.utc(2026, 10, 14).httpdate
    helper.set_last_modified(Time.utc(2026, 10, 15))
  end
end