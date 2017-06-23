require 'spec_helper'

RSpec.describe SnapshotAggregateRoot do
  class TestAggregate
    include SnapshotAggregateRoot

    def apply_snapshot(snapshot)
    end

    def build_snapshot
    end

    def apply_test_event(event)
    end
  end

  TestEvent = Class.new(RubyEventStore::Event)
  SnapshotEvent = Class.new(RubyEventStore::Event)

  let(:snapshot) { nil }
  let(:aggregate) { TestAggregate.new }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:event_store) { double 'EventStore' }

  before do
    SnapshotAggregateRoot.configure do |config|
      config.default_event_store = event_store
    end
  end

  describe '#load' do
    let(:events) { Array.new(5) { TestEvent.new } }
    let(:snapshot) { nil }

    before do
      allow(event_store).to receive(:last_stream_snapshot).with(aggregate_id).and_return(snapshot)
    end

    context 'when there is no snapshot' do
      before do
        allow(event_store).to receive(:read_events_forward).with(aggregate_id, count: 0).and_return(events)
      end

      it "loads all the events" do
        expect(event_store).to receive(:read_events_forward).with(aggregate_id, count: 0).and_return(events)
        aggregate.load(aggregate_id, event_store: event_store)
      end

      it "applies the events" do
        expect(aggregate).to receive(:apply_test_event).exactly(events.count).times
        aggregate.load(aggregate_id, event_store: event_store)
      end

      it "counts the events" do
        aggregate.load(aggregate_id, event_store: event_store)
        expect(aggregate.events_since_snapshot).to eq(events.count)
      end
    end

    context 'when a snapshot is available' do
      let(:snapshot) { double "Snapshot", stream: aggregate_id, event_id: SecureRandom.uuid, snapshot: true }

      before do
        allow(event_store).to receive(:read_events_forward).with(aggregate_id, start: snapshot.event_id, count: 0).and_return(events)
      end

      it "loads the events since the snapshot" do
        expect(event_store).to receive(:read_events_forward).with(aggregate_id, start: snapshot.event_id, count: 0).and_return(events)
        aggregate.load(aggregate_id, event_store: event_store)
      end

      it "applies the events" do
        expect(aggregate).to receive(:apply_test_event).exactly(events.count).times
        aggregate.load(aggregate_id, event_store: event_store)
      end

      it "counts the events" do
        aggregate.load(aggregate_id, event_store: event_store)
        expect(aggregate.events_since_snapshot).to eq(events.count)
      end
    end
  end

  describe '#store' do
    let(:events) { Array.new(5) { TestEvent.new } }

    before do
      events.each { |e|
        aggregate.apply(e)
        expect(event_store).to receive(:append_to_stream).with(e, stream_name: aggregate_id).ordered
      }
    end

    it "adds the events to the count" do
      aggregate.events_since_snapshot = 10
      aggregate.store(aggregate_id, event_store: event_store)
      expect(aggregate.events_since_snapshot).to eq(10 + events.count)
    end

    it "writes the events" do
      aggregate.store(aggregate_id, event_store: event_store)
    end

    it "saves the events for later notification" do
      aggregate.store(aggregate_id, event_store: event_store)
      expect(aggregate.send(:unnotified_events)).to eq(events)
    end

    context "if a snapshot is required" do
      let(:snapshot_event) { SnapshotEvent.new }
      before do
        allow(aggregate).to receive(:requires_snapshot?).and_return(true)
        allow(aggregate).to receive(:build_snapshot).and_return(snapshot_event)
        allow(event_store).to receive(:publish_snapshot)
      end

      it "builds a snapshot event" do
        expect(aggregate).to receive(:build_snapshot).and_return(snapshot_event)
        aggregate.store(aggregate_id, event_store: event_store)
      end

      it "saves a record of the snapshot" do
        expect(event_store).to receive(:publish_snapshot).with(snapshot_event, stream_name: aggregate_id)
        aggregate.store(aggregate_id, event_store: event_store)
      end
    end
  end
end
