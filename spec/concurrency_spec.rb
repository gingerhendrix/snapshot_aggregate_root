require 'spec_helper'

RSpec.describe "Concurrency" do
  module ConcurrencySpec
    class Writer
      attr_accessor :aggregate_id, :event_store

      def initialize(aggregate_id, event_store)
        @aggregate_id = aggregate_id
        @event_store = event_store
      end

      def write
        SomeAggregate.new.with_write_context(aggregate_id, event_store: event_store) do |aggregate|
          aggregate.do_command
        end
      end
    end

    EventA = Class.new(RubyEventStore::Event)
    EventB = Class.new(RubyEventStore::Event)
    SnapshotEvent = Class.new(RubyEventStore::Event)

    class SomeAggregate
      include SnapshotAggregateRoot

      attr_reader :a_count, :b_count

      def initialize
        @a_count = 0
        @b_count = 0
      end

      def build_snapshot
        SnapshotEvent.new data: { a_count: @a_count, b_count: @b_count }
      end

      def do_command
        apply EventA.new
        sleep(rand / 10)
        apply EventB.new
      end

      def apply_snapshot(snapshot)
        @a_count = snapshot.data[:a_count]
        @b_count = snapshot.data[:b_count]
      end

      def apply_event_a(event)
        @a_count += 1
      end

      def apply_event_b(event)
        @b_count += 1
      end
    end
  end

  let(:event_store) { TransactionEventStore::Client.new repository: TransactionEventStoreMongoid::Repository.new }
  let(:aggregate_id) { "foo" }
  let(:write_count) { 20 }
  let(:thread_count) { 5 }
  let(:expected_snapshot_count) { (write_count*thread_count/25).floor }

  before do
    threads = (0...thread_count).map do |i|
      Thread.new {
        writer = ConcurrencySpec::Writer.new(aggregate_id, event_store)
        write_count.times do
          writer.write
        end
      }
    end
    threads.each(&:join)
  end

  it "should store the events in order" do
    all_events = event_store.read_events_forward(aggregate_id, count: 0)

    expect(all_events.select { |e| e.is_a?(ConcurrencySpec::EventA) }.count).to eq(write_count * thread_count)
    expect(all_events.select { |e| e.is_a?(ConcurrencySpec::EventB) }.count).to eq(write_count * thread_count)
    expect(all_events.select { |e| e.is_a?(ConcurrencySpec::SnapshotEvent) }.count).to eq(expected_snapshot_count)

    next_event_type = ConcurrencySpec::EventA
    all_events.each_with_index do |event, i|
      next if event.is_a? ConcurrencySpec::SnapshotEvent

      expect(event).to be_kind_of(next_event_type)
      if next_event_type == ConcurrencySpec::EventA
        next_event_type = ConcurrencySpec::EventB
      else
        next_event_type = ConcurrencySpec::EventA
      end
    end
  end

  it "should apply all the events" do
    aggregate = ConcurrencySpec::SomeAggregate.new.load(aggregate_id, event_store: event_store)
    expect(aggregate.a_count).to eq(write_count * thread_count)
    expect(aggregate.b_count).to eq(write_count * thread_count)
  end
end
