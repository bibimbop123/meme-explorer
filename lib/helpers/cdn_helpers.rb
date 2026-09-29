# frozen_string_literal: true

# CDN Helper Methods for Views
# Based on: REFACTORING_ROADMAP Phase 4, Task 6.1

module CDNHelpers
  # Generate CDN URL for CSS assets
  def cdn_css(path)
    path = "/css/#{path}" unless path.start_with?('/')
    path = "#{path}.css" unless path.end_with?('.css')
    CDNConfig.asset_url(path)
  end

  # Generate CDN URL for JavaScript assets
  def cdn_js(path)
    path = "/js/#{path}" unless path.start_with?('/')
    path = "#{path}.js" unless path.end_with?('.js')
    CDNConfig.asset_url(path)
  end

  # Generate CDN URL for image assets.
  #
  # BUG FIX: this only checked `path.start_with?('/')` to decide whether
  # to prepend "/images/" - a real, already-absolute external URL (e.g.
  # "https://i.redd.it/foo.jpg" or "https://i.imgur.com/bar.png", which
  # is what most meme images actually are - see @image_src throughout
  # views/random/*.erb) doesn't start with "/" either, so it would have
  # been mangled into "/images/https://i.redd.it/foo.jpg" and then
  # prefixed with our own CDN domain on top of that - completely
  # breaking the image, not just failing to optimize it. CDNConfig's own
  # asset_url/image_url already correctly return absolute URLs
  # unchanged (`return path if path.start_with?('http')`), but that
  # check happens too late here, after this method has already
  # corrupted the path. This CDN only ever applies to our own local
  # static assets (public/images/*) - a real external meme URL must
  # pass through completely untouched.
  def cdn_image(path)
    return path if path.start_with?('http://') || path.start_with?('https://')

    # BUG FIX: real local meme paths (data/memes.yml's `file:` values,
    # e.g. "images/wholesome2.jpeg") already include "images/" but with
    # NO leading slash - this method's own doc comment describes callers
    # passing a bare filename like "meme.jpg", but that's not what's
    # actually stored anywhere. The original `path = "/images/#{path}"
    # unless path.start_with?('/')` logic, given a real value like
    # "images/wholesome2.jpeg" (no leading slash), prepended "/images/"
    # a second time -> "/images/images/wholesome2.jpeg", a real 404.
    # Strip a leading "images/" (with or without a leading slash) before
    # re-adding exactly one "/images/" prefix, so every real input shape
    # actually seen in this codebase - "foo.jpg", "images/foo.jpg", and
    # "/images/foo.jpg" - normalizes to the same correct "/images/foo.jpg".
    normalized = path.sub(%r{\A/?images/}, '')
    CDNConfig.image_url("/images/#{normalized}")
  end

  # Generate CDN URL for any static asset
  def cdn_asset(path)
    CDNConfig.asset_url(path)
  end

  # Preload critical CSS (use in <head>)
  def preload_css(*paths)
    paths.map do |path|
      url = cdn_css(path)
      %(<link rel="preload" href="#{url}" as="style">)
    end.join("\n")
  end

  # Preload critical JS (use in <head>)
  def preload_js(*paths)
    paths.map do |path|
      url = cdn_js(path)
      %(<link rel="preload" href="#{url}" as="script">)
    end.join("\n")
  end

  # Preload critical images (use in <head>)
  def preload_image(*paths)
    paths.map do |path|
      url = cdn_image(path)
      %(<link rel="preload" href="#{url}" as="image">)
    end.join("\n")
  end

  # Generate responsive image srcset
  def cdn_image_srcset(base_path, sizes = [1, 2, 3])
    sizes.map do |size|
      path = base_path.sub(/(\.\w+)$/, "@#{size}x\\1")
      "#{cdn_image(path)} #{size}x"
    end.join(", ")
  end
end
