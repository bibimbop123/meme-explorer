# Dark Mode Quick Start Guide 🌓

## Quick Start - Test Dark Mode NOW

### Step 1: Start the Server
```bash
# In your terminal, run:
bundle exec ruby app.rb
```

### Step 2: Open Browser
Navigate to: http://localhost:4567

### Step 3: Test Dark Mode
Once the page loads, you should see:
- A **moon emoji (🌙)** button in the navigation bar
- Click it to toggle to dark mode → it changes to **sun emoji (☀️)**
- Click again to toggle back to light mode

### Alternative: Use Keyboard Shortcut
- Press `Cmd+K` (Mac) or `Ctrl+K` (Windows/Linux) to toggle dark mode

---

## What's Already Implemented

### ✅ Files Created:
1. **`public/css/theme.css`** - Complete theme system with CSS variables
2. **`views/layout.erb`** - Updated with dark mode button and JavaScript
3. **`public/css/meme_explorer.css`** - Has dark mode button styling

### ✅ Features Working:
- Toggle button with moon/sun emoji
- Keyboard shortcut (Cmd+K / Ctrl+K)
- System preference detection (auto dark mode if your OS is in dark mode)
- Persistent storage (remembers your choice in localStorage)
- Smooth color transitions
- No flash on page load

### ✅ What Changes in Dark Mode:
- Background: Light gray → Dark gray
- Text: Dark → Light
- Cards & containers adapt
- Borders adapt
- Shadows adapt

---

## Troubleshooting

### Server Won't Start?
```bash
# Install dependencies
bundle install

# Try starting again
bundle exec ruby app.rb
```

### Button Not Visible?
- Make sure server restarted after the changes
- Clear browser cache (Cmd+Shift+R or Ctrl+Shift+R)
- Check browser console for errors (F12)

### Dark Mode Not Working?
1. **Check the button is there**: Look for 🌙 in navigation
2. **Click the button**: Should switch to ☀️
3. **Check browser console**: Press F12, look for JavaScript errors
4. **Try keyboard shortcut**: Cmd+K or Ctrl+K
5. **Check localStorage**: In console, type `localStorage.getItem('theme')`

### Colors Not Changing?
- The theme.css file uses CSS variables
- Make sure your browser supports CSS custom properties
- Try hard refresh: Cmd+Shift+R (Mac) or Ctrl+F5 (Windows)

---

## Testing Checklist

Once server is running, test these:

- [ ] Page loads at http://localhost:4567
- [ ] Moon button (🌙) is visible in navigation
- [ ] Clicking button toggles to sun (☀️)
- [ ] Background changes from light to dark
- [ ] Text color inverts
- [ ] Clicking sun switches back to moon
- [ ] Keyboard shortcut Cmd+K works
- [ ] Refresh page - setting persists
- [ ] Open in new tab - setting persists

---

## How It Works

### 1. Theme Initialization (Before Page Renders)
```javascript
// In layout.erb <head>
const savedTheme = localStorage.getItem('theme');
if (savedTheme === 'dark') {
  document.documentElement.classList.add('dark-mode');
}
```

### 2. Toggle Button Click
```javascript
darkModeToggle.addEventListener('click', () => {
  html.classList.toggle('dark-mode');
  localStorage.setItem('theme', newIsDark ? 'dark' : 'light');
  darkModeToggle.textContent = newIsDark ? '☀️' : '🌙';
});
```

### 3. CSS Variables Switch
```css
:root {
  --bg-primary: #fefefe;  /* Light */
}

html.dark-mode {
  --bg-primary: #1a1a1a;  /* Dark */
}
```

---

## Need More Help?

### Check These Files:
1. `views/layout.erb` - Has the toggle button and JavaScript
2. `public/css/theme.css` - Theme variables and dark mode styles
3. `public/css/meme_explorer.css` - Button styling

### Browser Console Commands:
```javascript
// Check if dark mode is active
document.documentElement.classList.contains('dark-mode')

// Check saved preference
localStorage.getItem('theme')

// Manually toggle
document.documentElement.classList.toggle('dark-mode')
```

---

## Success! 🎉

If you see the moon/sun button and it toggles the theme, **dark mode is working!**

The system will:
- Remember your choice across sessions
- Respect your OS dark mode preference on first visit
- Work across all pages of the site
- Apply to all UI components

**Now start the server and test it! 🚀**

```bash
bundle exec ruby app.rb
```

Then open http://localhost:4567 and click that moon button! 🌙
