require_relative '../spec_helper'

RSpec.describe 'Opaque feed session identity' do
  def helper(state)
    Object.new.extend(AuthHelpers).tap do |instance|
      instance.define_singleton_method(:session) { state }
    end
  end

  it 'is stable in one session and isolated from other sessions' do
    first = helper({})
    second = helper({})
    id = first.feed_session_id
    expect(id).to match(/\A[a-f0-9]{64}\z/)
    expect(first.feed_session_id).to eq(id)
    expect(second.feed_session_id).not_to eq(id)
  end

  it 'replaces invalid stored identities instead of using legacy session or IP labels' do
    [nil, '', 'anonymous_127.0.0.1', '../other', 42].each do |invalid|
      state = { feed_session_id: invalid, session_id: 'legacy-session' }
      expect(helper(state).feed_session_id).to match(/\A[a-f0-9]{64}\z/)
    end
  end
end