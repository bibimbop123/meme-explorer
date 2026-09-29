# spec/helpers/cdn_helpers_spec.rb
#
# ROADMAP.md Phase 2 ("CDN integration" - README.md's Planned list):
# lib/helpers/cdn_helpers.rb + config/initializers/cdn.rb were both
# already written and CDNHelpers was already mixed into every route
# (`helpers CDNHelpers` in app.rb), but config/initializers/cdn.rb -
# which defines CDNConfig, the module CDNHelpers entirely delegates to -
# was never required anywhere in the codebase. Every real call to any
# CDNHelpers method would have raised `NameError: uninitialized constant
# CDNConfig`. Fixed the require in app.rb; this file covers both that
# fix and a second, real bug found while actually exercising this code
# for the first time: cdn_image's own path-normalization logic produced
# a double "/images/images/..." prefix for the exact path shape
# data/memes.yml's real `file:` values use.

require_relative '../spec_helper'

RSpec.describe CDNHelpers do
  include CDNHelpers

  after do
    # CDNConfig/CDN_ENABLED/CDN_DOMAIN are top-level constants set once
    # at require-time from ENV - reset them after any test that
    # temporarily changes ENV so later specs see the real, disabled-by-
    # default test-environment state again.
    ENV.delete('CDN_DOMAIN')
    ENV['RACK_ENV'] = 'test'
    Object.send(:remove_const, :CDN_DOMAIN) if defined?(CDN_DOMAIN)
    Object.send(:remove_const, :CDN_ENABLED) if defined?(CDN_ENABLED)
    load File.expand_path('../../config/initializers/cdn.rb', __dir__)
  end

  describe 'CDNConfig is actually loaded (the root bug fixed this session)' do
    it 'is defined, not raising NameError' do
      expect(defined?(CDNConfig)).to eq('constant')
    end

    it 'is disabled by default in the test environment' do
      expect(CDNConfig.enabled?).to eq(false)
    end
  end

  describe '#cdn_image' do
    it 'leaves an already-absolute https:// URL completely untouched' do
      url = 'https://i.redd.it/real_meme.jpg'
      expect(cdn_image(url)).to eq(url)
    end

    it 'leaves an already-absolute http:// URL completely untouched' do
      url = 'http://i.imgur.com/real_meme.png'
      expect(cdn_image(url)).to eq(url)
    end

    it 'normalizes a bare filename to /images/<file> (CDN disabled: unchanged path)' do
      expect(cdn_image('funny1.jpeg')).to eq('/images/funny1.jpeg')
    end

    it 'does not double-prefix a real data/memes.yml-shaped path ("images/foo.jpeg", no leading slash)' do
      # This is the actual shape stored in data/memes.yml's `file:`
      # values - confirmed via grep, e.g. `file: "images/wholesome2.jpeg"`.
      expect(cdn_image('images/wholesome2.jpeg')).to eq('/images/wholesome2.jpeg')
    end

    it 'does not double-prefix an already-rooted "/images/foo.jpeg" path' do
      expect(cdn_image('/images/wholesome2.jpeg')).to eq('/images/wholesome2.jpeg')
    end

    it 'rewrites to a real CDN URL, with exactly one /images/ segment, when a CDN domain is configured' do
      ENV['RACK_ENV'] = 'production'
      ENV['CDN_DOMAIN'] = 'cdn.example.com'
      Object.send(:remove_const, :CDN_DOMAIN) if defined?(CDN_DOMAIN)
      Object.send(:remove_const, :CDN_ENABLED) if defined?(CDN_ENABLED)
      load File.expand_path('../../config/initializers/cdn.rb', __dir__)

      result = cdn_image('images/wholesome2.jpeg')

      expect(result).to eq('https://cdn.example.com/images/wholesome2.jpeg')
      expect(result.scan('images/').size).to eq(1)
    end

    it 'still leaves an external URL untouched even when a CDN domain is configured' do
      ENV['RACK_ENV'] = 'production'
      ENV['CDN_DOMAIN'] = 'cdn.example.com'
      Object.send(:remove_const, :CDN_DOMAIN) if defined?(CDN_DOMAIN)
      Object.send(:remove_const, :CDN_ENABLED) if defined?(CDN_ENABLED)
      load File.expand_path('../../config/initializers/cdn.rb', __dir__)

      url = 'https://i.redd.it/real_meme.jpg'
      expect(cdn_image(url)).to eq(url)
    end
  end
end
