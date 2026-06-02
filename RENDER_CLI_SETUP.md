# Render CLI Setup & Usage Guide

## Install Render CLI

### macOS (Using Homebrew)
```bash
brew tap render-oss/render
brew install render
```

### Alternative: Download Binary
```bash
# Download latest version
curl -fsSL https://render.com/install | bash
```

### Verify Installation
```bash
≈
```

---

## Login to Render

```bash
render login
```

This will:
1. Open your browser
2. Ask you to authorize the CLI
3. Automatically authenticate your terminal session

---

## Connect to Your Production Service

### List Your Services
```bash
render services list
```

You should see `meme-explorer` in the list.

### SSH into Production Shell
```bash
render shell meme-explorer
```

This opens an interactive shell directly in your production environment!

---

## Run the Cache Refresh Script

Once you're connected via `render shell`, you'll be in the production environment. Run:

```bash
# You're already in the project directory
bundle exec ruby scripts/manual_cache_refresh.rb
```

That's it! The script will refresh the cache immediately.

---

## Quick One-Liner (Without Interactive Shell)

If you just want to run a single command without opening a shell:

```bash
render run meme-explorer -- bundle exec ruby scripts/manual_cache_refresh.rb
```

This executes the command and exits automatically.

---

## Useful Render CLI Commands

### View Logs
```bash
# Real-time logs
render logs meme-explorer --tail

# Last 100 lines
render logs meme-explorer --num 100
```

### View Service Status
```bash
render services info meme-explorer
```

### List Environment Variables
```bash
render env meme-explorer
```

### Restart Service
```bash
render services restart meme-explorer
```

---

## Full Workflow Example

```bash
# 1. Install CLI (one time)
brew tap render-oss/render
brew install render

# 2. Login (one time)
render login

# 3. SSH into production
render shell meme-explorer

# 4. Once connected, run the refresh script
bundle exec ruby scripts/manual_cache_refresh.rb

# 5. Exit when done
exit
```

---

## Troubleshooting

### "render: command not found"
The CLI isn't installed. Follow the installation steps above.

### "Authentication required"
Run `render login` first.

### "Service not found"
Make sure you're logged into the correct Render account:
```bash
render whoami
```

### CLI Hangs or Freezes
Try logging out and back in:
```bash
render logout
render login
```

---

## Alternative: Use Render Dashboard (Easier!)

If you don't want to install the CLI, you can use the **Render Dashboard Shell** instead:

1. Go to https://dashboard.render.com
2. Click on **meme-explorer** service
3. Click the **"Shell"** tab
4. Run: `bundle exec ruby scripts/manual_cache_refresh.rb`

**This is actually easier than the CLI!** No installation required.

---

## Which Should You Use?

| Method | Pros | Cons |
|--------|------|------|
| **Dashboard Shell** | ✅ No installation<br>✅ Always available<br>✅ Visual interface | ❌ Requires browser |
| **Render CLI** | ✅ Use from terminal<br>✅ Scriptable<br>✅ Faster for frequent use | ❌ Requires installation<br>❌ Need to login |

**Recommendation:** Use **Dashboard Shell** for quick one-off tasks. Use **CLI** if you access production frequently.

---

## Documentation

- Render CLI Docs: https://render.com/docs/cli
- GitHub Repo: https://github.com/render-oss/render-cli
