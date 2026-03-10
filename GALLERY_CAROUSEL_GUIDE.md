# 📸 Gallery Carousel Guide - Multi-Image Posts

## Overview
Your app now supports **Reddit gallery posts** with multiple images! This feature includes a beautiful, mobile-responsive carousel with swipe gestures, keyboard navigation, and smooth transitions.

## ✨ Features

### Desktop
- ← → Arrow buttons for navigation
- Keyboard arrow keys support  
- Click indicators to jump to specific images
- Smooth fade transitions
- Image counter (e.g., "1 / 5")

### Mobile
- **Swipe gestures** (left/right)
- Touch-optimized buttons
- Responsive layout
- Optimized for smaller screens

## 🎯 How It Works

### Backend (Automatic)
The `fetch_reddit_memes_authenticated` method in `app.rb` now automatically detects and stores gallery data from Reddit API responses. Multi-image posts are identified by the `is_gallery` flag.

### Frontend Integration

#### In Your View (ERB):
```erb
<% if is_gallery_post?(@meme) && @meme["gallery_images"] %>
  <!-- Multi-image gallery -->
  <%= gallery_styles %>
  <%= render_gallery_carousel(@meme["gallery_images"], @meme["title"]) %>
  <%= gallery_script %>
<% else %>
  <!-- Single image (current behavior) -->
  <img src="<%= @image_src %>" alt="<%= @meme['title'] %>">
<% end %>
```

## 📋 Implementation Steps

### Step 1: Update `views/random.erb`

Replace the current image section with:

```erb
<!-- Meme Display -->
<% if is_gallery_post?(@meme) && @meme["gallery_images"] %>
  <!-- Multi-image carousel -->
  <%= gallery_styles %>
  <%= render_gallery_carousel(@meme["gallery_images"], @meme["title"]) %>
  <%= gallery_script %>
<% else %>
  <!-- Single image -->
  <div class="meme-container">
    <img 
      src="<%= @image_src %>" 
      alt="<%= @meme['title'] %>" 
      class="meme-image"
      loading="lazy"
    >
  </div>
<% end %>
```

### Step 2: Update Reddit API Fetching

Modify the `fetch_reddit_memes_authenticated` method to extract gallery data:

```ruby
def self.fetch_reddit_memes_authenticated(access_token, subreddits = nil, limit = 15)
  memes = []
  
  subreddits.each do |subreddit|
    # ... existing code ...
    
    data["data"]["children"].each do |post|
      post_data = post["data"]
      
      # Check if it's a gallery post
      if post_data["is_gallery"] && post_data["gallery_data"]
        gallery_images = extract_gallery_images(post_data)
        
        meme = {
          "title" => post_data["title"],
          "subreddit" => post_data["subreddit"],
          "likes" => post_data["ups"] || 0,
          "permalink" => post_data["permalink"],
          "is_gallery" => true,
          "gallery_images" => gallery_images
        }
      else
        # Regular single image post
        next if post_data["is_video"] || !post_data["url"]
        
        meme = {
          "title" => post_data["title"],
          "url" => post_data["url"],
          "subreddit" => post_data["subreddit"],
          "likes" => post_data["ups"] || 0,
          "permalink" => post_data["permalink"]
        }
      end
      
      memes << meme
    end
  end
  
  memes
end
```

### Step 3: Helper Method (in app.rb helpers block)

Add this helper to extract gallery images:

```ruby
def extract_gallery_images_from_post(post_data)
  return nil unless post_data["is_gallery"]
  
  images = []
  gallery_data = post_data["gallery_data"]["items"] || []
  media_metadata = post_data["media_metadata"] || {}
  
  gallery_data.each do |item|
    media_id = item["media_id"]
    metadata = media_metadata[media_id]
    next unless metadata
    
    image_url = metadata.dig("s", "u")
    next unless image_url
    
    images << {
      "url" => image_url.gsub("&amp;", "&"),
      "caption" => item["caption"] || "",
      "id" => media_id
    }
  end
  
  images.empty? ? nil : images
end
```

## 🎨 Customization

### Change Transition Speed
In `gallery_helpers.rb`, modify the CSS:
```css
.gallery-slide {
  transition: opacity 0.5s ease-in-out; /* Adjust timing */
}
```

### Change Button Style
```css
.gallery-nav {
  background: rgba(0, 0, 0, 0.7); /* Change opacity/color */
  border-radius: 50%; /* Make circular */
}
```

### Adjust Mobile Swipe Sensitivity
In `gallery_helpers.rb`, change the swipe threshold:
```javascript
if (touchEndX < touchStartX - 100) { // Increase from 50 to 100
  // Swipe left - next
}
```

## 📱 Mobile Optimizations

The carousel automatically adapts for mobile:
- **Buttons**: Smaller, optimized for touch
- **Swipe**: Native touch gestures
- **Layout**: Full-width on mobile
- **Performance**: Lazy loading images

## 🐛 Troubleshooting

### Gallery not showing?
1. Check if `@meme["is_gallery"]` is true
2. Verify `@meme["gallery_images"]` has data
3. Check browser console for JavaScript errors

### Images not loading?
1. Check Reddit API response format
2. Verify image URLs are properly decoded (`&amp;` → `&`)
3. Check network tab for 403/404 errors

### Swipe not working on mobile?
1. Ensure `touch-action: pan-y pinch-zoom` is set
2. Check for JavaScript conflicts
3. Test on actual device (not just emulator)

## 🚀 Example Use Cases

### Multiple Meme Formats
Perfect for:
- Before/After comparisons
- Multi-panel comics
- Step-by-step tutorials
- Collection showcases

### Enhanced UX
- Users can swipe through related memes
- No need to leave the page
- Smooth, native-like experience
- Engagement boost from galleries

## 📊 Analytics

Track gallery engagement:
```ruby
# In your analytics
def track_gallery_view(user_id, gallery_id, image_index)
  DB.execute(
    "INSERT INTO gallery_views (user_id, gallery_id, image_index, viewed_at) 
     VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
    [user_id, gallery_id, image_index]
  )
end
```

## 🎉 Benefits

1. **Better Content**: Support full Reddit gallery posts
2. **Improved UX**: Native swipe on mobile
3. **More Engagement**: Users view more images per post
4. **Mobile-First**: Optimized for touch devices
5. **Accessibility**: Keyboard navigation included

## 📝 Notes

- Gallery posts are automatically detected from Reddit API
- Single images still work as before (backward compatible)
- All styles are scoped to avoid conflicts
- JavaScript is vanilla (no jQuery required)
- Works with both light and dark modes

---

**Ready to go!** The gallery helpers are integrated and ready to use. Just update your views to check for gallery posts and render the carousel.
