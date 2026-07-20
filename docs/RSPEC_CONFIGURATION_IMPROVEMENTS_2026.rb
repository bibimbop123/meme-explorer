# frozen_string_literal: true

# RSpec configuration improvements for better test reliability
# Add this to your spec/spec_helper.rb

RSpec.configure do |config|
  # Use documentation format for clearer test output
  config.default_formatter = 'doc' if config.files_to_run.one?
  
  # Show slowest examples
  config.profile_examples = 10
  
  # Randomize test order to catch order dependencies
  config.order = :random
  Kernel.srand config.seed
  
  # Filter lines from Rails gems in backtraces
  config.filter_rails_from_backtrace!
  
  # Database cleaner strategy
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
  
  # Redis cleanup between tests
  config.before(:each) do
    redis = Redis.new(url: ENV['REDIS_URL'])
    redis.flushdb if ENV['RACK_ENV'] == 'test'
  end
  
  # Shared examples for common patterns
  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # More helpful failure messages
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.max_formatted_output_length = 1000
  end
  
  # Mock framework configuration
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
  
  # Warnings as errors in CI
  config.warnings = true if ENV['CI']
end

# Shared examples for service objects
RSpec.shared_examples 'a service object' do
  it { is_expected.to respond_to(:call) }
  
  it 'returns a result object' do
    result = subject.call
    expect(result).to respond_to(:success?)
    expect(result).to respond_to(:failure?)
  end
end

# Shared examples for Redis-backed services
RSpec.shared_examples 'a Redis-backed service' do
  let(:redis) { Redis.new(url: ENV['REDIS_URL']) }
  
  after { redis.flushdb }
  
  it 'handles Redis connection failures gracefully' do
    allow(redis).to receive(:get).and_raise(Redis::CannotConnectError)
    
    expect { subject.call }.not_to raise_error
  end
end

# Custom matchers
RSpec::Matchers.define :be_valid_meme_data do
  match do |actual|
    actual.is_a?(Hash) &&
      actual.key?(:id) &&
      actual.key?(:title) &&
      actual.key?(:url) &&
      actual[:url] =~ URI::DEFAULT_PARSER.make_regexp
  end
  
  failure_message do |actual|
    "expected " + actual.to_s + " to be valid meme data with id, title, and valid URL"
  end
end
