require_relative '../spec_helper'
require 'erb'

RSpec.describe 'Viewer control semantics' do
  it 'escapes and encodes the initial community discovery link' do
    context = Object.new
    context.instance_variable_set(:@meme, { 'title' => 'Example', 'subreddit' => 'cats & dogs' })
    context.define_singleton_method(:collection_name_for_subreddit) { |_| '<Cats & dogs>' }
    context.define_singleton_method(:calculate_rarity) { |_| { label: 'Common' } }
    context.define_singleton_method(:generate_curation_signal) { |_| { type: 'default', icon: '', message: 'Community feed' } }
    context.instance_variable_set(:@reddit_path, nil)
    template = File.read(File.expand_path('../../views/random/metadata.erb', __dir__))
    html = ERB.new(template).result(context.instance_eval { binding })
    expect(html).to include('class="meme-subreddit"', '/search?q=cats+%26+dogs', '&lt;Cats &amp; dogs&gt;')
    expect(html).not_to include('<Cats & dogs>')
  end

  def controls(liked:, saved:)
    @liked = liked
    @saved = saved
    @likes = 12
    ERB.new(File.read(File.expand_path('../../views/random/controls.erb', __dir__))).result(binding)
  end

  it 'renders explicit button types and stable accessible names' do
    html = controls(liked: false, saved: false)
    expect(html.scan('<button type="button"').length).to eq(4)
    expect(html).to include('aria-label="Like this meme"', 'aria-label="Save this meme to favorites"',
      'aria-label="Share this meme"', 'aria-label="Download this meme"')
    expect(html).to include('</span> Like')
  end

  it 'reflects initial toggle state and keeps Previous unavailable on first entry' do
    html = controls(liked: true, saved: true)
    expect(html.scan('aria-pressed="true"').length).to eq(2)
    viewer = File.read(File.expand_path('../../views/random.erb', __dir__))
    expect(viewer).to match(/id="prev-btn"[^>]*disabled/)
    expect(controls(liked: false, saved: false).scan('aria-pressed="false"').length).to eq(2)
  end
end