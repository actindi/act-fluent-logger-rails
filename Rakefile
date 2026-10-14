require "bundler/gem_tasks"
require "rspec/core/rake_task"

INTEGRATION_SPECS = "spec/integration/**/*_spec.rb"

RSpec::Core::RakeTask.new("spec:unit") do |t|
  t.exclude_pattern = INTEGRATION_SPECS
end

# Each file boots its own Rails app, and a Rails app can only boot once per process.
desc "Run the specs against a real Rails app"
task "spec:integration" do
  failed = Dir[INTEGRATION_SPECS].sort.reject do |file|
    ruby("-S", "rspec", file) { |ok, _status| ok }
  end
  abort "Failed: #{failed.join(', ')}" if failed.any?
end

desc "Run all specs"
task :spec => ["spec:unit", "spec:integration"]

task :default => :spec
