require_relative '../spec_helper'
require_relative '../../lib/services/feed_acknowledgement_envelope'
require 'stringio'

RSpec.describe MemeExplorer::FeedAcknowledgementEnvelope do
  let(:id) { SecureRandom.hex(32) }
  let(:token) { SecureRandom.hex(32) }

  it 'classifies legacy IDs without claiming ownership or recording impressions' do
    expect(described_class.parse('impression_id' => id)).to eq(status: :legacy, impression_id: id)
  end

  it 'classifies a complete v2 envelope and excludes client attribution fields' do
    data = { 'impression_id' => id, 'impression_protocol' => 2, 'ack_token' => token,
             'user_id' => 99, 'url' => '/untrusted.jpg', 'reservation_token' => SecureRandom.hex(32) }
    expect(described_class.parse(data)).to eq(status: :versioned, impression_id: id, token: token)
  end

  it 'never falls back to a legacy ID when any new-protocol field is present' do
    [{ 'ack_token' => token }, { 'ack_token' => nil }, { 'impression_protocol' => 2 },
     { 'impression_protocol' => nil }, { 'impression_protocol' => 1, 'ack_token' => token },
     { 'impression_protocol' => '2', 'ack_token' => token },
     { 'impression_protocol' => 2.0, 'ack_token' => token },
     { 'impression_protocol' => 2, 'ack_token' => 'bad' }].each do |fields|
      expect(described_class.parse(fields.merge('impression_id' => id))).to eq(status: :invalid)
    end
  end

  it 'rejects malformed shapes and identifiers' do
    [nil, [], 'json', {}, { impression_id: id }, { 'impression_id' => id, :ack_token => token }].each do |data|
      expect(described_class.parse(data)).to eq(status: :invalid)
    end
    [nil, 42, id.upcase, 'a' * 63, 'a' * 65, "\xFF".dup.force_encoding(Encoding::UTF_8)].each do |value|
      expect(described_class.parse('impression_id' => value)).to eq(status: :invalid)
    end
  end

  it 'copies and freezes validated identifiers without freezing request data' do
    original_id, original_token = id.dup, token.dup
    data = { 'impression_id' => id, 'impression_protocol' => 2, 'ack_token' => token }
    versioned = described_class.parse(data)
    legacy = described_class.parse('impression_id' => id)
    id.replace('b' * 64)
    token.replace('c' * 64)
    data.clear
    expect(versioned).to eq(status: :versioned, impression_id: original_id, token: original_token)
    expect(legacy).to eq(status: :legacy, impression_id: original_id)
    expect(versioned).to be_frozen
    expect(legacy).to be_frozen
    expect(versioned[:impression_id]).to be_frozen
    expect(versioned[:token]).to be_frozen
    expect(legacy[:impression_id]).to be_frozen
    expect { versioned[:token].replace('bad') }.to raise_error(FrozenError)
  end

  it 'reads bounded legacy and v2 JSON bodies through the same no-fallback classifier' do
    expect(described_class.read(StringIO.new(JSON.generate('impression_id' => id)))).to eq(status: :legacy, impression_id: id)
    payload = JSON.generate('impression_id' => id, 'impression_protocol' => 2, 'ack_token' => token)
    expect(described_class.read(StringIO.new(payload))).to eq(status: :versioned, impression_id: id, token: token)
    expect(described_class.read(StringIO.new(JSON.generate('impression_id' => id, 'ack_token' => nil)))).to eq(status: :invalid)
  end

  it 'accepts the exact byte boundary and reads no more than the bounded oversize sentinel' do
    payload = JSON.generate('impression_id' => id)
    exact = payload + ' ' * (described_class::MAX_BODY_BYTES - payload.bytesize)
    expect(described_class.read(StringIO.new(exact))[:status]).to eq(:legacy)
    stream = StringIO.new(exact + ' ' * 10_000)
    expect(described_class.read(stream)).to eq(status: :invalid)
    expect(stream.pos).to eq(described_class::MAX_BODY_BYTES + 1)
  end

  it 'rejects malformed, deeply nested and unreadable JSON bodies' do
    ['', '{', '[]', 'null', '[' * 5 + '0' + ']' * 5, "\xFF".dup.force_encoding(Encoding::UTF_8)].each do |raw|
      expect(described_class.read(StringIO.new(raw))).to eq(status: :invalid)
    end
    stream = StringIO.new('')
    stream.close
    expect(described_class.read(stream)).to eq(status: :invalid)
  end

  it 'rejects duplicate decoded JSON keys rather than choosing a credential value' do
    bodies = [
      %({"impression_id":"#{id}","impression_id":"#{id}"}),
      %({"impression_id":"#{id}","impression_protocol":1,"impression_protocol":2,"ack_token":"#{token}"}),
      %({"impression_id":"#{id}","impression_protocol":2,"ack_token":null,"ack_token":"#{token}"}),
      %({"impression_id":"#{id}","impression_protocol":2,"ack_token":"#{token}","ack_\\u0074oken":"#{token}"}),
      %({"impression_id":"#{id}","extra":{"key":1,"key":2}})
    ]
    bodies.each { |raw| expect(described_class.read(StringIO.new(raw))).to eq(status: :invalid) }
  end
end