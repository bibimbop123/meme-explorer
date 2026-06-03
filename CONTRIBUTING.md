# 🤝 CONTRIBUTING TO MEME EXPLORER

Thank you for your interest in contributing! This guide will help you get started.

---

## 🚀 QUICK START

### Prerequisites
- Ruby 3.2.1
- PostgreSQL (production) or SQLite (development)
- Redis
- Git

### Setup
```bash
# 1. Clone the repository
git clone https://github.com/bibimbop123/meme-explorer.git
cd meme-explorer

# 2. Install dependencies
bundle install

# 3. Set up environment variables
cp .env.example .env
# Edit .env with your credentials

# 4. Run database migrations
bundle exec ruby scripts/setup_database.rb

# 5. Start the development server
bundle exec ruby app.rb
# Or use: ./scripts/start_dev_server.sh
```

---

## 📋 DEVELOPMENT WORKFLOW

### 1. Create a Branch
```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes
- Write clean, documented code
- Follow Ruby style guide (RuboCop)
- Add tests for new features

### 3. Run Tests
```bash
# Run all tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/services/meme_service_spec.rb

# Check coverage
COVERAGE=true bundle exec rspec
```

### 4. Lint Your Code
```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop --auto-correct
```

### 5. Commit Your Changes
```bash
git add .
git commit -m "feat: add awesome feature"
```

**Commit Message Format:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance

### 6. Push and Create PR
```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

---

## 🏗️ CODE STANDARDS

### Ruby Style
- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use meaningful variable names

### Service Pattern
```ruby
# Good: Service class with single responsibility
class MemeService
  def self.fetch_trending(limit: 50)
    # Implementation
  end
end

# Usage
MemeService.fetch_trending(limit: 100)
```

### Error Handling
```ruby
# Always use proper error handling
begin
  risky_operation
rescue SpecificError => e
  AppLogger.error("Context", error: e)
  Sentry.capture_exception(e)
  # Provide fallback
end
```

### Testing
```ruby
# Write descriptive tests
RSpec.describe MemeService do
  describe '.fetch_trending' do
    it 'returns an array of memes' do
      result = MemeService.fetch_trending(limit: 10)
      expect(result).to be_an(Array)
      expect(result.size).to be <= 10
    end
    
    it 'handles API failures gracefully' do
      allow(HTTParty).to receive(:get).and_raise(Timeout::Error)
      result = MemeService.fetch_trending
      expect(result).to eq([])
    end
  end
end
```

---

## 📝 DOCUMENTATION

### Code Comments
```ruby
# For complex logic, add explanatory comments
# Calculate engagement score using weighted formula:
# - Likes count 2x more than views
# - Apply time decay for older memes
score = (likes * 2 + views) * time_decay_factor
```

### YARD Documentation
```ruby
##
# Fetches trending memes from Reddit
#
# @param limit [Integer] Maximum number of memes to return
# @param offset [Integer] Pagination offset
# @return [Array<Hash>] Array of meme objects
# @raise [APIError] if Reddit API is unavailable
def fetch_trending(limit: 50, offset: 0)
  # Implementation
end
```

---

## 🧪 TESTING GUIDELINES

### Test Coverage
- Aim for 80%+ coverage on new code
- 100% coverage on critical paths (auth, payments, etc.)
- Use SimpleCov to track coverage

### Test Types
1. **Unit Tests:** Test individual methods
2. **Integration Tests:** Test service interactions
3. **Request Tests:** Test HTTP endpoints

### Running Specific Tests
```bash
# Run tests for a specific file
bundle exec rspec spec/services/meme_service_spec.rb

# Run tests matching a pattern
bundle exec rspec -t focus

# Run with seed for reproducibility
bundle exec rspec --seed 12345
```

---

## 🔒 SECURITY

### Never Commit
- API keys or secrets
- `.env` files
- Database credentials
- Session secrets

### Input Validation
```ruby
# Always validate and sanitize user input
def search_memes(query)
  sanitized_query = InputSanitizer.sanitize_search_query(query)
  return [] if sanitized_query.empty?
  
  # Use parameterized queries
  DB.execute("SELECT * FROM memes WHERE title LIKE ?", ["%#{sanitized_query}%"])
end
```

---

## 🐛 DEBUGGING

### Local Debugging
```ruby
# Use binding.pry for interactive debugging
require 'pry'
binding.pry  # Execution stops here
```

### Logging
```ruby
# Use AppLogger for consistent logging
AppLogger.info("Meme fetched", meme_id: meme.id, user_id: user.id)
AppLogger.error("API failed", error: e.message, context: context)
```

---

## 📚 USEFUL RESOURCES

- **Architecture:** See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)  
- **API Docs:** See [API_DOCS.md](API_DOCS.md)
- **Roadmap:** See [NEXT_90_DAYS_ROADMAP_JUNE_2026.md](NEXT_90_DAYS_ROADMAP_JUNE_2026.md)

---

## 💬 GETTING HELP

- **Issues:** Open an issue on GitHub
- **Questions:** Start a GitHub Discussion
- **Bugs:** Use the bug report template

---

## 📜 LICENSE

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing! 🎉**
