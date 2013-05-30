# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'web_images_parser/version'

Gem::Specification.new do |spec|
  spec.name          = "web_images_parser"
  spec.version       = WebImagesParser::VERSION
  spec.authors       = ["edikgat"]
  spec.email         = ["edikgat@gmail.com"]
  spec.description   = "Gem for parsing images from web pages"
  spec.summary       = "Gem for parsing images from web pages"
  spec.homepage      = "https://github.com/edikgat/web_images_parser"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  
  spec.add_runtime_dependency "rest-client", "~> 1.6"
  spec.add_runtime_dependency "multi_json", "~> 1.3"
end
