# frozen_string_literal: true
require 'rbconfig'

root = File.expand_path('..', __dir__)
expected = File.read(File.join(root, '.ruby-version')).strip
failures = []
puts "Ruby executable: #{RbConfig.ruby}"
puts "Ruby version: #{RUBY_VERSION}; expected: #{expected}"
failures << 'Ruby version does not match .ruby-version' unless RUBY_VERSION == expected
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