# frozen_string_literal: true
require 'rbconfig'

root = File.expand_path('..', __dir__)
expected = File.read(File.join(root, '.ruby-version')).strip
failures = []
puts "Ruby executable: #{RbConfig.ruby}"
puts "Ruby version: #{RUBY_VERSION}; expected series: #{expected}"
# Patch-tolerant: the Gemfile directive is "~> 3.2.1" and CI resolves the
# latest 3.2.x patch (ubuntu-26.04 only builds the newest patch per
# series), so require the same major.minor series, not an exact patch.
running_series = Gem::Version.new(RUBY_VERSION).segments.first(2)
expected_series = Gem::Version.new(expected).segments.first(2)
failures << "Ruby series #{RUBY_VERSION} does not match .ruby-version series #{expected}" unless running_series == expected_series
paths = ENV['RUBYLIB'].to_s.split(File::PATH_SEPARATOR)
bundler_only = !paths.empty? && paths.all? { |path| path.start_with?(File.join(root, 'vendor/bundle/bootstrap/gems/bundler-')) && path.end_with?('/lib') }
puts "RUBYLIB override: #{paths.empty? ? 'absent' : (bundler_only ? 'isolated Bundler bootstrap only (no native override)' : 'present (results may depend on local workaround)')}"

%w[bundler/setup bcrypt date psych pg puma/puma_http11].each do |library|
  begin
    require library
    puts "PASS: #{library}"
  rescue LoadError, StandardError => e
    failures << library
    warn "FAIL: #{library}: #{e.class}: #{e.message}"
  end
end

if failures.empty?
  puts 'Ruby dependency load checks passed. This does not replace the test suite.'
  exit 0
end
warn 'Ruby environment checks failed. See docs/RUBY_ENVIRONMENT.md; do not overwrite shared gems.'
exit 1