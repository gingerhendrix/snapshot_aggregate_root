# SnapshotAggregateRoot

An extension of https://github.com/arkency/aggregate_root with support for concurrent writers.

## Usage

### Snapshots

Snapshots are created automatically as required by the `#store` method.  Implementations of this class must implement
2 methods.

* `#build_snapshot`
* `#apply_snapshot(snapshot)`

Optionally Implementations may also override

* `#snapshot_threshold` - Override how often snapshots are taken
* `#requires_snapshot?`- Provide a custom implementation for when snapshots a required


### Concurrent Writers

In order to be safe for current writes snapshot aggregate root exposes a `#with_write_context(stream_name, event_store:)` method. This method loads the aggregate, applies the block, then stores the events within a mutex so that only one concurrent writer can execute the block.  Event handlers are triggered after the command is complete

The entire command handler for a snapshot aggregate root should be executed within this block eg.

```
  def apply_command(command)
    SomeAggregate.new.with_write_context(command.aggregate_id) do |aggregate|
      aggregate.do_command(command)
    end
  end
```

