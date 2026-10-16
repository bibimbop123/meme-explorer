require_relative '../spec_helper'
require_relative '../../lib/middleware/security_headers'

RSpec.describe 'Opt-in CSP report-only rollout' do
  before do
    allow(ENV).to receive(:[]).and_call_original
  end

  it 'is disabled by default and preserves normal caching' do
    allow(ENV).to receive(:[]).with('CSP_REPORT_ONLY').and_return(nil)
    app = SecurityHeaders.new(->(_env) { [200, { 'Cache-Control' => 'public, max-age=60' }, ['ok']] })
    _, headers, = app.call({})
    expect(headers).not_to have_key('Content-Security-Policy-Report-Only')
    expect(headers['Cache-Control']).to eq('public, max-age=60')
  end

  it 'generates a fresh nonce before rendering and retains enforced CSP' do
    allow(ENV).to receive(:[]).with('CSP_REPORT_ONLY').and_return('true')
    nonces = []
    app = SecurityHeaders.new(->(env) { nonces << env['meme.csp_nonce']; [200, {}, ['ok']] })
    2.times do
      status, headers, = app.call({})
      expect(status).to eq(200)
      expect(headers).to have_key('Content-Security-Policy')
      expect(headers['Content-Security-Policy-Report-Only']).to include("'nonce-#{nonces.last}'", "script-src-attr 'none'")
      expect(headers['Content-Security-Policy-Report-Only']).not_to include('unsafe-inline', 'strict-dynamic')
      expect(headers['Cache-Control']).to include('no-store')
    end
    expect(nonces.uniq.size).to eq(2)
  end

  it 'renders layout scripts with the request nonce' do
    nonce = SecureRandom.base64(24)
    get '/login', {}, { 'meme.csp_nonce' => nonce }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("<script nonce=\"#{nonce}\" src=\"/js/csrf.js\"")
    expect(last_response.body).not_to include('<script src=')
  end
end