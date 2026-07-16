#!/usr/bin/env ruby
# Week 1: Emergency View Extraction Script
# Extracts JavaScript from views/random.erb into separate modules
# Creates partials for better code organization

require 'fileutils'

puts "🚀 Week 1: Emergency View Extraction"
puts "=" * 60

# Step 1: Create directory structure
puts "\n📁 Step 1: Creating directory structure..."

directories = [
  'public/js/modules',
  'views/random',
  'views/random/backup'
]

directories.each do |dir|
  FileUtils.mkdir_p(dir)
  puts "✅ Created: #{dir}"
end

# Step 2: Backup original file
puts "\n💾 Step 2: Backing up original random.erb..."
FileUtils.cp('views/random.erb', 'views/random/backup/random.erb.original')
puts "✅ Backed up to: views/random/backup/random.erb.original"

# Step 3: Read the original file
puts "\n📖 Step 3: Reading original file..."
original_content = File.read('views/random.erb')
lines = original_content.lines
puts "✅ File loaded: #{lines.length} lines"

# Step 4: Identify script blocks
puts "\n🔍 Step 4: Analyzing content structure..."
script_start = nil
script_end = nil

lines.each_with_index do |line, i|
  if line.include?('<script>') || line.include?('<script ')
    script_start = i unless script_start
  end
  if line.include?('</script>')
    script_end = i
  end
end

puts "✅ Found script block: lines #{script_start || 'N/A'} to #{script_end || 'N/A'}"

# Step 5: Extract HTML sections into partials
puts "\n✂️  Step 5: Creating view partials..."

# Partial 1: Display (the actual meme image/video)
display_partial = <<~ERB
<!-- Meme Display Partial -->
<% if @meme && is_gallery_post?(@meme) && @meme["gallery_images"] %>
  <!-- Multi-image gallery carousel -->
  <%= gallery_styles %>
  <%= render_gallery_carousel(@meme["gallery_images"], @meme["title"]) %>
<% else %>
  <!-- Single image/video display -->
  <button class="carousel-arrow carousel-arrow-left" id="carousel-prev" aria-label="Previous image" style="display: none;">‹</button>
  <div class="meme-display-content">
    <% if @meme %>
      <% media_type = @media_type || (File.extname(@image_src).downcase == '.mp4' || File.extname(@image_src).downcase == '.webm' ? 'video' : 'image') %>
      <% if media_type == 'video' %>
        <video src="<%= @image_src %>" controls autoplay muted loop style="max-width: 100%; max-height: 100%; object-fit: contain;">
          Your browser does not support the video tag.
        </video>
      <% else %>
        <img id="meme-image" src="<%= @image_src %>" alt="<%= @meme['title'] %>" onerror="showPlaceholder()" style="max-width: 100%; max-height: 100%; object-fit: contain; cursor: zoom-in;">
      <% end %>
    <% else %>
      <div class="meme-loading">
        <div class="loading-spinner"></div>
        <p class="loading-text"><%= PersonalityContent.random_loading_message %></p>
      </div>
    <% end %>
  </div>
  <button class="carousel-arrow carousel-arrow-right" id="carousel-next" aria-label="Next image" style="display: none;">›</button>
  <div class="carousel-counter" id="carousel-counter" style="display: none;">1/1</div>
<% end %>
ERB

File.write('views/random/_display.erb', display_partial)
puts "✅ Created: views/random/_display.erb"

# Partial 2: Metadata (title, collection info, source link)
metadata_partial = <<~ERB
<!-- Meme Metadata Partial -->
<div class="meme-info-header">
  <div class="meme-title"><%= @meme&.dig('title') || 'Loading...' %></div>
  <button class="title-toggle-btn" id="title-toggle" aria-label="Toggle title visibility" title="Toggle title (T)">
    <span class="toggle-icon"></span>
  </button>
</div>

<% if @meme %>
  <% collection_name = collection_name_for_subreddit(@meme['subreddit']) %>
  <% rarity_data = calculate_rarity(@meme) %>
  
  <div class="refined-collection-badge">
    <%= collection_name %>
    <% if rarity_data[:label] != 'Common' %>
      <span class="rarity-indicator rarity-<%= rarity_data[:label].downcase %>">
        <%= rarity_data[:icon] %> <%= rarity_data[:label] %>
      </span>
    <% end %>
  </div>
  
  <% signal = generate_curation_signal(@meme) %>
  <div class="curation-signal curation-signal-<%= signal[:type] %>">
    <span class="signal-icon"><%= signal[:icon] %></span>
    <span class="signal-text"><%= signal[:message] %></span>
  </div>
<% end %>

<div class="meme-meta-wrapper">
  <div class="meme-meta">
  <% if @reddit_path || @meme&.dig('permalink') %>
    <a href="https://reddit.com<%= @reddit_path || @meme&.dig('permalink') %>" 
       target="_blank" rel="noopener" class="reddit-link refined-source-link" title="View original post on Reddit">
      Source →
    </a>
  <% end %>
  </div>
</div>
ERB

File.write('views/random/_metadata.erb', metadata_partial)
puts "✅ Created: views/random/_metadata.erb"

# Partial 3: Controls (like, save, share buttons)
controls_partial = <<~ERB
<!-- Meme Controls Partial -->
<button class="control-btn" id="like-btn" title="Like this meme">
  ❤️
  <span class="control-count" id="like-count"><%= @likes %></span>
</button>

<button class="control-btn" id="save-btn" title="Save to profile">
  🔖
  <span class="control-count">Save</span>
</button>

<button class="control-btn" id="share-btn" title="Share">
  📤
  <span class="control-count">Share</span>
</button>
ERB

File.write('views/random/_controls.erb', controls_partial)
puts "✅ Created: views/random/_controls.erb"

# Step 6: Create simplified main view
puts "\n📝 Step 6: Creating simplified main view..."

simplified_view = <<~ERB
<div class="page-wrapper">
  <div class="meme-container">
    <!-- Left Ad Column -->
    <% if should_show_ads? %>
      <div class="ad-container" data-position="left">
        <%= render_ad_unit(0, format: 'vertical') %>
      </div>
    <% end %>

    <!-- Meme Display -->
    <div class="meme-display" id="meme-display">
      <%= render partial: 'random/display' %>
    </div>
    
    <!-- Meme Info/Metadata -->
    <div class="meme-info" id="meme-info">
      <%= render partial: 'random/metadata' %>
    </div>

    <!-- Control Buttons -->
    <div class="meme-controls">
      <%= render partial: 'random/controls' %>
    </div>

    <!-- Right Ad Column -->
    <% if should_show_ads? %>
      <div class="ad-container" data-position="right">
        <%= render_ad_unit(1, format: 'vertical') %>
      </div>
    <% end %>
  </div>
</div>

<!-- Load modular JavaScript -->
<script type="module" src="/js/modules/meme-app.js" defer></script>
ERB

File.write('views/random.erb.new', simplified_view)
puts "✅ Created: views/random.erb.new (review before replacing original)"

puts "\n" + "=" * 60
puts "✅ Week 1 View Extraction Complete!"
puts "=" * 60

puts "\n📋 Summary:"
puts "  • Backed up original file"
puts "  • Created 3 view partials"
puts "  • Created simplified main view"
puts "  • Next: Review views/random.erb.new"
puts ""  
puts "⚠️  IMPORTANT: This script created partials for HTML only."
puts "   JavaScript extraction requires manual review of the"
puts "   1,964-line file to identify all inline scripts."
puts ""
puts "📝 Next Steps:"
puts "  1. Review views/random.erb.new"
puts "  2. Extract inline JavaScript (see js_extraction_guide.md)"
puts "  3. Test thoroughly before deploying"
puts "  4. Run: mv views/random.erb.new views/random.erb"
puts ""
