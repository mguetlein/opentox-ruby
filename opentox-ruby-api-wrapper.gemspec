# Generated by jeweler
# DO NOT EDIT THIS FILE
# Instead, edit Jeweler::Tasks in Rakefile, and run `rake gemspec`
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{opentox-ruby-api-wrapper}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christoph Helma"]
  s.date = %q{2009-08-17}
  s.description = %q{Ruby wrapper for the OpenTox REST API (http://www.opentox.org)}
  s.email = %q{helma@in-silico.ch}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/helper.rb",
     "lib/opentox-ruby-api-wrapper.rb",
     "lib/spork.rb",
     "opentox-ruby-api-wrapper.gemspec",
     "test/hamster_carcinogenicity.csv",
     "test/opentox-ruby-api-wrapper_test.rb",
     "test/start-local-webservices.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/helma/opentox-ruby-api-wrapper}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Ruby wrapper for the OpenTox REST API}
  s.test_files = [
    "test/test_helper.rb",
     "test/opentox-ruby-api-wrapper_test.rb",
     "test/start-local-webservices.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rest-client>, [">= 0"])
    else
      s.add_dependency(%q<rest-client>, [">= 0"])
    end
  else
    s.add_dependency(%q<rest-client>, [">= 0"])
  end
end
