# QUICK START IMPLEMENTATION GUIDE

**For:** Engineering Team  
**Duration:** Week 1 (Days 2-5)  
**Goal:** Complete Phase 1 security hardening  
**Effort:** 13 hours  

---

## 🎯 YOUR MISSION THIS WEEK

Complete validator integration in 3 remaining route groups to achieve **82/100 security score**.

**Done Already (✅):**
- `routes/auth.rb` - Signup/login secured
- `app.rb` - CSRF protection active
- `lib/validators.rb` - Module complete

**Your Tasks (⏳):**
1. Search routes validation (2h) - **HIGHEST PRIORITY**
2. Profile routes validation (2h)
3. Admin routes validation (1.5h)
4. Create security test suite (6.5h)

---

## 📍 TASK 1: SECURE SEARCH ROUTES (2 hours)

### WHERE TO EDIT
**File:** `routes/memes.rb`  
**Section:** The `/search` endpoint

### CURRENT CODE (VULNERABLE)
```ruby
get "/search" do
  query = params[:q]  # ❌ NO VALIDATION
  
  results = @memes.select { |m| m["title"].downcase.include?(query.downcase) }
  erb :search, locals: { results: results, query: query }
end
```

### SECURE CODE (USE THIS)
```ruby
# At top of file, add:
require_relative '../lib/validators'

# Then replace search endpoint with:
get "/search" do
  begin
    # Validate and sanitize search query
    query = Validators.validate_search_query(params[:q])
    page = Validators.validate_page(params[:page] || 1)
    per_page = Validators.validate_per_page(params[:per_page] || 10, max: 50)
    
    # Search with validated parameters
    results = search_memes(query)
    
    # Paginate results
    offset = (page - 1) * per_page
    paginated_results = results[offset...(offset + per_page)] || []
    
    if request.accept.include?("application/json")
      content_type :json
      {
        query: query,
        results: paginated_results,
        page: page,
        total: results.size,
        pages: (results.size / per_page.to_f).ceil
      }.to_json
    else
      erb :search, locals: { 
        results: paginated_results, 
        query: query,
        total: results.size,
        page: page
      }
    end
    
  rescue Validators::ValidationError => e
    halt 422, { success: false, error: e.message }.to_json
  end
end

# Helper method to search (add to helpers section)
def search_memes(query)
  query_lower = query.downcase.strip
  
  # Search in cache first (fast)
  cache_results = (MEME_CACHE.get(:memes) || []).select do |m|
    (m["title"]&.downcase&.include?(query_lower) ||
     m["subreddit"]&.downcase&.include?(query_lower))
  end
  
  # If too few, search DB
  if cache_results.size < 5
    db_results = DB.execute(
      "SELECT * FROM meme_stats WHERE title LIKE ? COLLATE NOCASE LIMIT 50",
      ["%#{query_lower}%"]
    ).map { |r| r.transform_keys(&:to_s) }
    cache_results = (cache_results + db_results).uniq { |m| m["url"] }
  end
  
  cache_results
end
```

### VERIFICATION
```bash
# Test with valid query
curl "http://localhost:4567/search?q=funny&page=1"
# Expected: 200 with JSON results

# Test with invalid query (too long)
curl "http://localhost:4567/search?q=$(python -c 'print(\"a\" * 300)')"
# Expected: 422 with error message
```

---

## 📍 TASK 2: SECURE PROFILE ROUTES (2 hours)

### WHERE TO EDIT
**File:** `routes/profile.rb`  
**Sections:** Profile get/post endpoints

### CURRENT CODE (VULNERABLE)
```ruby
get "/profile" do
  user_id = session[:user_id]  # ✅ OK
  # But parameters not validated below:
end

post "/profile/update" do
  username = params[:username]  # ❌ NO VALIDATION
  email = params[:email]        # ❌ NO VALIDATION
  
  DB.execute("UPDATE users SET username = ?, email = ? WHERE id = ?", 
             [username, email, session[:user_id]])
end
```

### SECURE CODE (USE THIS)
```ruby
# At top of file, add:
require_relative '../lib/validators'

# Replace profile update with:
post "/profile/update" do
  begin
    halt 401, { success: false, error: "Not logged in" }.to_json unless session[:user_id]
    
    # Whitelist and validate parameters
    safe_params = Validators.whitelist_params(params,
      allowed_keys: [:username, :email],
      optional_keys: [:email]
    )
    
    # Validate each field
    username = Validators.validate_username(safe_params[:username])
    email = Validators.validate_email(safe_params[:email]) if safe_params[:email]
    
    # Update with validated data
    if email
      DB.execute(
        "UPDATE users SET username = ?, email = ? WHERE id = ?",
        [username, email, session[:user_id]]
      )
    else
      DB.execute(
        "UPDATE users SET username = ? WHERE id = ?",
        [username, session[:user_id]]
      )
    end
    
    session[:username] = username
    
    content_type :json
    { success: true, message: "Profile updated", user: { username: username, email: email } }.to_json
    
  rescue Validators::ValidationError => e
    halt 422, { success: false, error: e.message }.to_json
  rescue => e
    halt 500, { success: false, error: "Update failed" }.to_json
  end
end

# Also secure get profile:
get "/profile" do
  begin
    user_id = session[:user_id]
    halt 401, "Not logged in" unless user_id
    
    @user = DB.execute("SELECT * FROM users WHERE id = ?", [user_id]).first
    halt 404, "User not found" unless @user
    
    @saved_memes = DB.execute(
      "SELECT * FROM saved_memes WHERE user_id = ? ORDER BY saved_at DESC LIMIT 50",
      [user_id]
    )
    
    erb :profile
  rescue => e
    halt 500, "Error loading profile: #{e.message}"
  end
end
```

### VERIFICATION
```bash
# Test invalid username (too short)
curl -X POST http://localhost:4567/profile/update \
  -d "username=ab&email=test@example.com" \
  -H "Cookie: session=valid_session_id"
# Expected: 422 with "username must be at least 3 characters"

# Test valid update
curl -X POST http://localhost:4567/profile/update \
  -d "username=newname&email=new@example.com" \
  -H "Cookie: session=valid_session_id"
# Expected: 200 with success message
```

---

## 📍 TASK 3: SECURE ADMIN ROUTES (1.5 hours)

### WHERE TO EDIT
**File:** `routes/admin.rb`  
**Sections:** All endpoints

### PATTERN
All admin endpoints should follow this pattern:

```ruby
# At top of file, add:
require_relative '../lib/validators'

# For any admin endpoint:
post "/admin/meme/:id/moderate" do
  begin
    # 1. Security check
    halt 403, { error: "Not admin" }.to_json unless is_admin?
    
    # 2. Validate parameters
    meme_id = Validators.validate_id(params[:id])
    action = Validators.validate_enum(params[:action], 
      allowed_values: ["approve", "reject", "flag"],
      field_name: "action")
    reason = Validators.sanitize_string(params[:reason] || "", max_length: 500)
    
    # 3. Perform action with validated data
    case action
    when "approve"
      DB.execute("UPDATE meme_stats SET flagged = 0 WHERE id = ?", [meme_id])
    when "reject"
      DB.execute("UPDATE meme_stats SET hidden = 1 WHERE id = ?", [meme_id])
    when "flag"
      DB.execute("UPDATE meme_stats SET flagged = 1 WHERE id = ?", [meme_id])
    end
    
    # 4. Log action
    DB.execute(
      "INSERT INTO admin_logs (admin_id, action, meme_id, reason) VALUES (?, ?, ?, ?)",
      [session[:user_id], action, meme_id, reason]
    )
    
    content_type :json
    { success: true, action: action, meme_id: meme_id }.to_json
    
  rescue Validators::ValidationError => e
    halt 422, { success: false, error: e.message }.to_json
  rescue => e
    halt 500, { success: false, error: "Action failed" }.to_json
  end
end
```

---

## 📍 TASK 4: CREATE SECURITY TEST SUITE (6.5 hours)

### WHERE TO CREATE
**File:** `spec/security/validators_spec.rb` (NEW FILE)

### BASIC STRUCTURE
```ruby
require 'spec_helper'

RSpec.describe Validators do
  describe '.validate_email' do
    it 'accepts valid email' do
      result = Validators.validate_email('user@example.com')
      expect(result).to eq('user@example.com')
    end
    
    it 'rejects invalid email' do
      expect {
        Validators.validate_email('invalid')
      }.to raise_error(Validators::ValidationError)
    end
    
    it 'lowercases email' do
      result = Validators.validate_email('USER@EXAMPLE.COM')
      expect(result).to eq('user@example.com')
    end
  end
  
  describe '.validate_username' do
    it 'accepts valid username' do
      result = Validators.validate_username('valid_user')
      expect(result).to eq('valid_user')
    end
    
    it 'rejects username < 3 chars' do
      expect {
        Validators.validate_username('ab')
      }.to raise_error(Validators::ValidationError)
    end
  end
  
  describe '.sanitize_string' do
    it 'removes XSS attacks' do
      result = Validators.sanitize_string("<script>alert('xss')</script>hello")
      expect(result).not_to include('<script>')
    end
  end
end
```

### RUN TESTS
```bash
bundle exec rspec spec/security/validators_spec.rb
# Should pass all tests
```

---

## ⏱️ TIME BREAKDOWN

| Task | Hours | Status |
|------|-------|--------|
| Search routes | 2h | ⏳ Start Monday |
| Profile routes | 2h | ⏳ Monday/Tuesday |
| Admin routes | 1.5h | ⏳ Wednesday |
| Security tests | 6.5h | ⏳ Wednesday-Friday |
| **Total Week 1** | **11.5h** | **13 hours with buffer** |

---

## ✅ ACCEPTANCE CRITERIA FOR EACH TASK

### Search Routes
- [x] Parameters validated with Validators module
- [x] Invalid queries return 422 with error message
- [x] Valid queries return results
- [x] Pagination works (page, per_page)

### Profile Routes
- [x] Username/email validated
- [x] Invalid data returns 422
- [x] Valid data updates database
- [x] User session updated

### Admin Routes
- [x] All parameters validated
- [x] Non-admins get 403
- [x] Invalid actions return 422
- [x] Valid actions perform operation and log

### Security Tests
- [x] All validators have happy path test
- [x] All validators have error case test
- [x] XSS prevention verified
- [x] At least 20 test cases

---

## 🚨 COMMON MISTAKES TO AVOID

❌ **DON'T:** Skip validation "because it's internal"
✅ **DO:** Validate ALL user input

❌ **DON'T:** Return detailed error messages to users
✅ **DO:** Log details server-side, return generic message to user

❌ **DON'T:** Put `require` in every method
✅ **DO:** Put it once at top of file

❌ **DON'T:** Forget to rescue validation errors
✅ **DO:** Catch `Validators::ValidationError` and return 422

---

## 💬 IF YOU GET STUCK

**Problem:** "Validators module not found"
**Solution:** Add `require_relative '../lib/validators'` at top of file

**Problem:** "route not found error"
**Solution:** Make sure you're editing the CORRECT file (routes/memes.rb, not app.rb)

**Problem:** "tests won't run"
**Solution:** Make sure spec_helper exists and run: `bundle exec rspec spec/security/validators_spec.rb`

---

## 🎯 SUCCESS CRITERIA FOR WEEK 1

- [x] All 3 route groups have validators integrated
- [x] All validators working (tested manually)
- [x] 20+ security test cases passing
- [x] No regressions in existing functionality
- [x] Security score: 68 → **82/100** ✅

---

## 📋 SIGN-OFF CHECKLIST

When complete, verify:
- [ ] `routes/memes.rb` - Search validation added
- [ ] `routes/profile.rb` - Profile validation added
- [ ] `routes/admin.rb` - Admin validation added
- [ ] `spec/security/validators_spec.rb` - Tests created
- [ ] `bundle exec rspec` - All tests passing
- [ ] Manual testing - Invalid input returns 422
- [ ] Manual testing - Valid input works as before

---

**You've got this! 💪**

Questions? Check `SECURITY_AUDIT_REPORT.md` for details or review `lib/validators.rb` for all available methods.
