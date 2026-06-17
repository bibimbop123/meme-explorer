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

  # Generate CDN URL for image assets
  def cdn_image(path)
    path = "/images/#{path}" unless path.start_with?('/')
    CDNConfig.image_url(path)
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
