$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'snapshot_aggregate_root'
require 'transaction_event_store_mongoid'

Mongoid.load!("spec/mongoid.yml", :test)

RSpec.configure do |spec|
  spec.before(:each) do
    Mongoid.purge!
    SnapshotAggregateRoot.configure do |config|
      config.default_event_store = nil
    end
  end
end
