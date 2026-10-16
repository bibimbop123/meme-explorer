require_relative '../spec_helper'
require_relative '../../lib/security/public_origin'

RSpec.describe PublicOrigin do
  def resolve(value, production: true)
    described_class.resolve(configured: value, production: production, fallback: 'http://localhost:4567')
  end

  it 'accepts HTTPS origins and removes a trailing slash' do
    expect(resolve('https://memes.example:8443/')).to eq('https://memes.example:8443')
  end

  it 'never falls back to the request origin in production' do
    [nil, '', 'http://memes.example', 'https://user@memes.example',
     'https://memes.example/path', 'https://memes.example?q=1',
     'https://memes.example#fragment', "https://memes.example\n"].each do |value|
      expect(resolve(value)).to be_nil
    end
  end

  it 'allows local fallback only when configuration is absent outside production' do
    expect(resolve(nil, production: false)).to eq('http://localhost:4567')
    expect(resolve('invalid', production: false)).to be_nil
  end
end