gemspec = Gem::Specification.new do |s|
  s.name = 'slash'
  s.version = '0.4.4'
  s.date = '2010-03-10'
  s.authors = ['Igor Gunko']
  s.email = 'tekmon@gmail.com'
  s.summary = 'REST-client'
  s.description = <<-EOS
    REST-client
  EOS
  s.homepage = 'http://github.com/omg/slash'
  s.rubygems_version = '1.3.1'

  s.require_paths = %w(lib)

  s.files = %w(
    README.rdoc MIT-LICENSE Rakefile
    lib/slash.rb
    lib/slash/exceptions.rb
    lib/slash/connection.rb
    lib/slash/nethttp.rb
    lib/slash/typhoeus.rb
    lib/slash/resource.rb
    lib/slash/formats.rb
    lib/slash/json.rb
    lib/slash/peanuts.rb
  )

  s.test_files = %w(
    spec/resource_spec.rb
  )

  s.has_rdoc = true
  s.rdoc_options = %w(--line-numbers --main README.rdoc)
  s.extra_rdoc_files = %w(README.rdoc MIT-LICENSE)

  s.add_dependency('extlib', ["~> 0.9.14"])
  s.add_dependency('addressable', ["~> 2.1.1"])

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency('rspec', ['~> 1.2.8'])
      s.add_development_dependency('typhoeus', ['~> 0.1.22'])
      s.add_development_dependency('peanuts', ['~> 2.1.1'])
      s.add_development_dependency('json', ['~> 1.2.2'])
    else
    end
  else
  end
end
