# 🚨 SECURITY INCIDENT: .env File Exposed in Git

**Date**: May 13, 2026  
**Severity**: HIGH  
**Status**: PARTIALLY MITIGATED

---

## Incident Summary

The `.env` file containing API keys and secrets was accidentally tracked in git, despite being listed in `.gitignore`. This file has been removed from git tracking but **may still exist in git history**.

---

## Immediate Actions Taken ✅

1. ✅ Removed .env from git tracking: `git rm --cached .env`
2. ✅ Verified .env is in .gitignore (line 2)

---

## CRITICAL: Next Steps Required

### Step 1: Commit the Removal
```bash
git add .gitignore
git commit -m "Security: Remove .env from git tracking"
```

### Step 2: Check if Pushed to GitHub
```bash
git log --all --full-history -- .env
```

If this shows commits, check if you've pushed to GitHub:
```bash
git remote -v
git log origin/main --oneline
```

### Step 3: If Pushed to GitHub - REGENERATE ALL KEYS

**Exposed credentials need to be revoked/regenerated:**

1. **Reddit API Keys**
   - REDDIT_CLIENT_ID
   - REDDIT_CLIENT_SECRET
   - Go to: https://www.reddit.com/prefs/apps
   - Delete old app or regenerate credentials

2. **Session Secret**
   - SESSION_SECRET  
   - Generate new: `ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'`

3. **Sentry DSN** (if present)
   - SENTRY_DSN
   - Regenerate at: https://sentry.io/settings/

4. **Any Database URLs**
   - REDIS_URL
   - DATABASE_URL
   - Rotate if using external services

### Step 4: Remove from Git History (If Pushed)

**WARNING**: This rewrites history and requires force push!

```bash
# Use BFG Repo Cleaner (safest method)
brew install bfg
bfg --delete-files .env
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (⚠️ destructive!)
git push origin --force --all
git push origin --force --tags
```

**Alternative** (git filter-branch):
```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

git push origin --force --all
```

### Step 5: Prevent Future Incidents

✅ Already done: `.env` is in `.gitignore`

**Additional safeguards:**
```bash
# Pre-commit hook to prevent .env commits
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
if git rev-parse --verify HEAD >/dev/null 2>&1
then
    against=HEAD
else
    against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

# Check for .env file
if git diff --cached --name-only $against | grep -q "^\.env$"
then
    echo "🚨 ERROR: Attempting to commit .env file!"
    echo "This file contains secrets and should never be committed."
    exit 1
fi
EOF

chmod +x .git/hooks/pre-commit
```

---

## What Was Exposed?

Check `.env` file contents to determine what secrets were exposed:
```bash
cat .env | grep -v "^#" | grep -v "^$"
```

Common sensitive variables:
- API keys (Reddit, Sentry, etc.)
- Database credentials
- Session secrets
- OAuth tokens
- Private URLs

---

## Timeline

- **May 13, 2026 06:40 AM**: Discovered .env tracked in git
- **May 13, 2026 06:40 AM**: Removed from tracking with `git rm --cached`
- **PENDING**: Commit removal
- **PENDING**: Check if pushed to GitHub
- **PENDING**: Regenerate exposed keys if needed

---

## Lessons Learned

1. **Always verify `.gitignore` works** - File was in .gitignore but still tracked (likely added before .gitignore was created)
2. **Use git hooks** - Prevent sensitive files from being committed
3. **Audit regularly** - Run `git ls-files` to check tracked files
4. **Secrets scanning** - Use tools like `gitleaks` or `truffleHog`

---

## Follow-up Actions

- [ ] Commit .env removal
- [ ] Check git log for .env history  
- [ ] Verify if pushed to GitHub
- [ ] Regenerate ALL exposed keys
- [ ] Remove from git history if needed
- [ ] Install pre-commit hook
- [ ] Set up secrets scanning (GitHub Advanced Security or gitleaks)
- [ ] Document in incident log

---

## Contact

If you need help with key regeneration:
- Reddit: https://www.reddit.com/prefs/apps
- Sentry: https://sentry.io/settings/
- Generate secrets: `ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'`

---

**Status**: .env removed from tracking, but **ACTION REQUIRED** to complete remediation.
