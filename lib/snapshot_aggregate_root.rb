require 'active_support/inflector'
require 'snapshot_aggregate_root/version'
require 'snapshot_aggregate_root/configuration'
require 'snapshot_aggregate_root/default_apply_strategy'

module SnapshotAggregateRoot
  attr_accessor :events_since_snapshot

  def apply(event)
    apply_strategy.(self, event)
    unpublished_events << event
  end

  def with_lock(stream_name, event_store: default_event_store, &block)
    event_store.with_lock(stream_name, &block)
  end

  def with_write_context(stream_name, event_store: default_event_store)
    with_lock(stream_name, event_store: event_store) do
      load(stream_name, event_store: event_store)
      yield self
      store(stream_name, event_store: event_store)
    end
    notify(event_store: event_store)
  end

  def load(stream_name, event_store: default_event_store)
    @loaded_from_stream_name = stream_name

    snapshot = event_store.last_stream_snapshot(stream_name)
    if snapshot
      apply_snapshot(snapshot)
      events = event_store.read_events_forward(stream_name, start: snapshot.event_id, count: 0)
    else
      events = event_store.read_events_forward(stream_name, count: 0)
    end

    events.each(&method(:apply))
    self.events_since_snapshot = events.count
    @unpublished_events = nil
    self
  end

  def store(stream_name = loaded_from_stream_name, event_store: default_event_store)
    self.events_since_snapshot += @unpublished_events.count
    unpublished_events.each do |event|
      event_store.append_to_stream(event, stream_name: stream_name)
      unnotified_events.push(event)
    end
    @unpublished_events = nil
    if requires_snapshot?
      snapshot!(stream_name, event_store: event_store)
    end
  end

  def notify(event_store: )
    unnotified_events.each do |event|
      event_store.notify_subscribers(event)
    end
    @unnotified_events = nil
  end

  def events_since_snapshot
    @events_since_snapshot || 0
  end

  private

  attr_reader :loaded_from_stream_name

  # This method must be implemented by consumers of this module
  #
  # Returns an Event
  def build_snapshot
    raise "build_snapshot not implemented in #{self}"
  end

  # This method must be implemented by consumers of this module
  #
  # Returns an Event
  def apply_snapshot(snapshot)
    raise "apply_snapshot not implemented in #{self}"
  end

  def requires_snapshot?
    events_since_snapshot >= snapshot_threshold
  end

  def snapshot_threshold
    50
  end

  def snapshot!(stream_name, event_store:)
    event = build_snapshot
    event_store.publish_snapshot(event, stream_name: stream_name)
  end

  def unpublished_events
    @unpublished_events ||= []
  end

  def unnotified_events
    @unnotified_events ||= []
  end

  def apply_strategy
    DefaultApplyStrategy.new
  end

  def default_event_store
    SnapshotAggregateRoot.configuration.default_event_store
  end
end
