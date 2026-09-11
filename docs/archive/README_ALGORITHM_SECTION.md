## Random Meme Algorithm

Our intelligent meme selection algorithm delivers fresh, diverse content with zero repetition.

### Key Features

- **🎯 Zero Repetition:** Never see the same meme twice in a session
- **🤖 Context-Aware:** Adapts to time-of-day and user preferences
- **⚡ Lightning Fast:** <100ms selection time
- **🔄 Auto-Fallback:** Graceful degradation if Redis fails
- **📊 Analytics:** Async tracking without blocking requests

### Architecture

```
Route → Controller → [MemePool, DiversityEngine, ViewingHistory] → Result
```

For detailed documentation, see [docs/RANDOM_ALGORITHM.md](docs/RANDOM_ALGORITHM.md)

### Quick Start

```ruby
# Get a random meme
result = MemeExplorer::RandomMemeController.handle(
  session: session,
  user_id: current_user_id,
  request_ip: request.ip
)

@meme = result.meme
@image_src = result.image_src
```

### Configuration

All algorithm parameters are in `config/algorithm_config.yml`:

```yaml
algorithm:
  selection:
    top_percentile: 0.2  # Top 20% of scored memes
  viewing_history:
    ttl_seconds: 7200    # 2 hours
    max_size: 200
```

### Testing

```bash
# Run integration tests
bundle exec rspec spec/integration/random_algorithm_integration_spec.rb
```
