# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'httprecognizer/version'

Gem::Specification.new do |spec|
  spec.name          = "httprecognizer"
  spec.version       = HttpRecognizer::VERSION
  spec.authors       = ["Kirk Haines"]
  spec.email         = ["wyhaines@gmail.com"]

  spec.summary       = %q{A very simple implementation of an HTTP Recognizer. Less than a parser, but more than nothing.}
  spec.description   = %q{The HttpRecognizer receives streamed HTTP, and when it accumulates enough to identify that it's seen an HTTP header, it attempts to extract some basic information from it. This is not a parser, and it is woefully incomplete, but for many tasks it understands just enough HTTP to be useful.}
  spec.homepage      = "http://github.com/wyhaines/httprecognizer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.require_paths = ["lib"]
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_dependency "deque", "> 0"
end
