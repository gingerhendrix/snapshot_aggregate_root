# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'snapshot_aggregate_root/version'

Gem::Specification.new do |spec|
  spec.name          = 'snapshot_aggregate_root'
  spec.version       = SnapshotAggregateRoot::VERSION
  spec.licenses      = ['MIT']
  spec.authors       = ['Gareth Andrew']
  spec.email         = ['gingerhendrix@gmail.com']

  spec.summary       = %q{Event sourced aggregate root implementation with concurrent writer and snapshot support}
  spec.description   = %q{Event sourced aggregate root implementation with concurrent writer and snapshot support}
  spec.homepage      = 'https://github.com/gingerhendrix/snapshot_aggregate_root'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rails', '~> 4.2.1'
  spec.add_development_dependency 'transaction_event_store_mongoid', '~> 0.0.1'

  spec.add_dependency 'activesupport', '>= 3.0'
  spec.add_dependency 'transaction_event_store', '~> 0.0.1'
end
