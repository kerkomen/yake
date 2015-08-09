# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "yake"
  spec.version       = '0.0.1'
 spec.authors       = ["Daniel"]
  spec.email         = []
  spec.summary       = %q{Pipeline-building tool compatible with Make}
  spec.description   = %q{Yake is a tool for working with Yakefiles as a Makefile preprocessor.}
  spec.homepage      = "https://github.com/kerkomen/yake"
  spec.license       = "MIT"

  spec.files         = ['lib/yake.rb']
  spec.executables   = ['bin/yake']
  spec.test_files    = ['spec/yakefile_spec.rb']
  spec.require_paths = ["lib"]
end
