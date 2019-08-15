# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-jsource/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-jsource'
  spec.version       = CocoapodsJsource::VERSION
  spec.authors       = ['handa']
  spec.email         = ['794363716@qq.com']
  spec.description   = %q{ Add source code debugging capabilities to binary.}
  spec.summary       = %q{ Add source code debugging capabilities to binary.}
  spec.homepage      = 'https://github.com/wendstation/cocoapods-jsource'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.add_dependency 'cocoapods'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
