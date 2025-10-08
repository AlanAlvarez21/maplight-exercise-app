ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load dotenv only if the gem is available and needed
begin
  require "dotenv/load"
rescue LoadError
  # dotenv is not available, which is fine in production
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
