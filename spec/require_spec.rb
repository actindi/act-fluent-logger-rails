require 'rbconfig'

describe 'requiring act-fluent-logger-rails' do
  it 'does not load unrelated active_support core extensions' do
    lib = File.expand_path('../lib', __dir__)
    script = <<~RUBY
      require 'logger'
      require 'active_support'
      require 'act-fluent-logger-rails'
      puts $LOADED_FEATURES.grep(%r{active_support/core_ext/(date|date_time|time|numeric)/})
    RUBY
    output = IO.popen([RbConfig.ruby, '-I', lib, '-e', script], &:read)

    expect($?).to be_success
    expect(output).to eq('')
  end
end
