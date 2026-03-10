#!/bin/bash
# Setup Tattoo Annie Social Media Preview Image
# This script helps you set up the Tattoo Annie image for social media sharing

echo "🎨 Tattoo Annie Social Media Preview Setup"
echo "=========================================="
echo ""

IMAGE_PATH="public/images/tattoo-annie-placeholder.jpg"

# Check if image already exists
if [ -f "$IMAGE_PATH" ]; then
  echo "✅ Tattoo Annie image already exists at: $IMAGE_PATH"
  
  # Check file size
  FILE_SIZE=$(wc -c < "$IMAGE_PATH" | tr -d ' ')
  FILE_SIZE_KB=$((FILE_SIZE / 1024))
  echo "📊 Current file size: ${FILE_SIZE_KB}KB"
  
  if [ $FILE_SIZE_KB -gt 1024 ]; then
    echo "⚠️  Warning: File size is over 1MB. Consider optimizing for faster loading."
    echo ""
    echo "Optimize with ImageMagick (if installed):"
    echo "  convert $IMAGE_PATH -quality 85 -resize 1200x630 ${IMAGE_PATH}.optimized.jpg"
  else
    echo "✅ File size is good!"
  fi
  
  # Check dimensions
  if command -v identify &> /dev/null; then
    DIMENSIONS=$(identify -format "%wx%h" "$IMAGE_PATH" 2>/dev/null)
    echo "📐 Image dimensions: $DIMENSIONS"
    echo ""
    echo "Recommended dimensions for social media:"
    echo "  - Facebook/Twitter: 1200x630 (1.91:1 ratio)"
    echo "  - Instagram: 1080x1080 (1:1 ratio)"
    echo "  - Current ratio works but may be cropped"
  fi
  
  echo ""
  echo "✅ Image setup complete! Next steps:"
  echo "1. Deploy your app to production"
  echo "2. Test with Facebook Debugger: https://developers.facebook.com/tools/debug/"
  echo "3. Test with Twitter Card Validator: https://cards-dev.twitter.com/validator"
  echo "4. Share your URL on social media!"
  
else
  echo "❌ Image not found at: $IMAGE_PATH"
  echo ""
  echo "📝 MANUAL SETUP REQUIRED:"
  echo ""
  echo "Please save the Tattoo Annie image you have to:"
  echo "  $PWD/$IMAGE_PATH"
  echo ""
  echo "You can do this by:"
  echo "1. Right-click the image in your browser/finder"
  echo "2. Select 'Save Image As...'"
  echo "3. Navigate to: $PWD/public/images/"
  echo "4. Save as: tattoo-annie-placeholder.jpg"
  echo ""
  echo "After saving the image, run this script again to verify!"
fi

echo ""
echo "=========================================="
echo "📚 For more information, see:"
echo "  - SOCIAL_MEDIA_PREVIEW_SETUP.md"
echo "  - TATTOO_ANNIE_PLACEHOLDER_GUIDE.md"
