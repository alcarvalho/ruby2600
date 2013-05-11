# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :rspec do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/ruby2600/(.+)\.rb}) { |m| "spec/lib/ruby2600/#{m[1]}_spec.rb" }
  watch(%r{^spec/support/shared_examples_for_(.+)\.rb}) {
                                      |m| "spec/lib/ruby2600/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')      { "spec" }
  watch(%r{^support/.+_spec\.rb$})  { "spec" }
end

guard :bundler do
  watch('Gemfile')
end
