# Append your first event

## Append your first event

The simplest way to append an event to EventStoreDB is to create an `EventStoreClient::DeserializedEvent` object and call `#append_to_stream` method.

```ruby
class SomethingHappened < EventStoreClient::DeserializedEvent
end

event = SomethingHappened.new(
  id: SecureRandom.uuid, type: 'some-event', data: { user_id: SecureRandom.uuid, title: "Something happened" }
)

EventStoreClient.client.append_to_stream('some-stream', [event])
```

## Working with EventStoreClient::DeserializedEvent

When appending events to EventStoreDB they must first all be wrapped in an `EventStoreClient::DeserializedEvent` object. This allows you to specify the content of the event and the type of event.

A sample of creating of event:

```ruby
EventStoreClient::DeserializedEvent.new(
  # Id of event. Optional. If omitted - its value will be generated using `SecureRandom.uuid`
  id: SecureRandom.uuid,
  # Event name. Optional. If omitted - its value will be generated using `self.class.to_s`
  type: 'some-event-name', 
  # Event data. Optional. Will default to `{}`(empty hash) if omitted
  data: { foo: :bar },
  # Optional. Defaults to `{ 'type' => event_name_you_provided, 'content-type' => 'application/json' }`
  metadata: {}
)
```

### Duplicated event id

If two events with the same id are appended to the same stream in quick succession EventStoreDB will only append one copy of the event to the stream.

```ruby
class SomethingHappened < EventStoreClient::DeserializedEvent
end

event = SomethingHappened.new(
  id: SecureRandom.uuid, type: 'some-event', data: {},
)
EventStoreClient.client.append_to_stream('some-stream', [event])
# Attempt to append the same event again. Will return the same result as for previous call
EventStoreClient.client.append_to_stream('some-stream', [event])
```


##  Handling concurrency

When appending events to a stream you can supply a stream state or stream revision. Your client can use this to tell EventStoreDB what state or version you expect the stream to be in when you append. If the stream isn't in that state then an exception will be thrown.

For example if we try and append the same record twice expecting both times that the stream doesn't exist we will get an exception on the second:

```ruby
class SomethingHappened < EventStoreClient::DeserializedEvent
end

event1 = SomethingHappened.new(
  type: 'some-event', data: {},
)

event2 = SomethingHappened.new(
  type: 'some-event', data: {},
)

stream_name = "some-stream$#{SecureRandom.uuid}"

EventStoreClient.client.append_to_stream(stream_name, [event1], options: { expected_revision: 'no_stream' })

EventStoreClient.client.append_to_stream(stream_name, [event2], options: { expected_revision: 'no_stream' })
```

There are three available stream states:

- `any`
- `no_stream`
- `stream_exists`

This check can be used to implement optimistic concurrency. When you retrieve a stream from EventStoreDB, you take note of the current version number, then when you save it back you can determine if somebody else has modified the record in the meantime.

```ruby
class SomethingHappened < EventStoreClient::DeserializedEvent
end

revision = EventStoreClient.client.read('some-stream').value!.last&.stream_revision || 0

event1 = SomethingHappened.new(
  type: 'some-event', data: {},
)
event2 = SomethingHappened.new(
  type: 'some-event', data: {},
)
EventStoreClient.client.append_to_stream('some-stream', [event1], options: { expected_revision: revision })

# Will fail with revisions mismatch error
EventStoreClient.client.append_to_stream('some-stream', [event2], options: { expected_revision: revision })
```