gemspec = Gem::Specification.new do |s|
  s.name = 'unrest'
  s.version = '0.1'
  s.date = '2009-10-01'
  s.authors = ['Igor Gunko']
  s.email = 'tekmon@gmail.com'
  s.summary = 'REST-client'
  s.description = <<-EOS
    REST-client
  EOS
  s.homepage = 'http://github.com/omg/unrest'
  s.rubygems_version = '1.3.1'

  s.require_paths = %w(lib)

  s.files = %w(
    README.rdoc MIT-LICENSE Rakefile
    lib/unrest.rb
    lib/omg-unrest.rb
    lib/unrest/exceptions.rb
    lib/unrest/connection.rb
    lib/unrest/resource.rb
    lib/unrest/formats.rb
    lib/unrest/json.rb
    lib/unrest/peanuts.rb
  )

  s.test_files = %w(
    spec/resource_spec.rb
  )

  s.has_rdoc = true
  s.rdoc_options = %w(--line-numbers --main README.rdoc)
  s.extra_rdoc_files = %w(README.rdoc MIT-LICENSE)

  #s.add_dependency('json', [">= 1.1.9"])
  #s.add_dependency('peanuts', [">= 2.0.8"])

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency('rspec', ['>= 1.2.8'])
    else
    end
  else
  end
end
