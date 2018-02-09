# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudscopes/version'

Gem::Specification.new do |spec|
  spec.name          = "cloudscopes"
  spec.version       = Cloudscopes::VERSION
  spec.authors       = ["Oded Arbel"]
  spec.email         = ["oded@geek.co.il"]
  spec.summary       = %q{Ruby gem to report system statistics to web based monitoring services such as CloudWatch}
  spec.description   = %q{Ruby gem to report system statistics to web based monitoring services such as CloudWatch}
  spec.homepage      = "http://github.com/guss77/cloudscopes"
  spec.license       = "GPLv3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = ["README.md"]

  spec.add_dependency 'aws-sdk-cloudwatch', '~> 1'
  spec.add_dependency 'sys-filesystem', '~> 1.1'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
