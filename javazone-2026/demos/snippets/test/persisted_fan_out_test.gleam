import gleam/erlang/process
import gleam/list
import persisted_fan_out

pub fn publish_still_reaches_every_subscriber_test() {
  let assert Ok(started) = persisted_fan_out.start()
  let publisher = started.data

  let subscriber = process.new_subject()
  process.send(publisher, persisted_fan_out.Subscribe(subscriber))
  process.send(publisher, persisted_fan_out.Publish("hello"))

  assert process.receive(subscriber, 100) == Ok("hello")
}

pub fn published_events_are_retained_in_mnesia_test() {
  let assert Ok(started) = persisted_fan_out.start()
  let publisher = started.data

  process.send(publisher, persisted_fan_out.Publish("first"))
  process.send(publisher, persisted_fan_out.Publish("second"))

  // Publish has no reply to wait on, so give the actor a beat to finish
  // before reading straight out of Mnesia rather than through it.
  process.sleep(50)

  let events = persisted_fan_out.events_for(started.pid)
  assert list.contains(events, "first")
  assert list.contains(events, "second")
}

pub fn a_late_subscriber_can_catch_up_from_mnesia_test() {
  let assert Ok(started) = persisted_fan_out.start()
  let publisher = started.data

  process.send(publisher, persisted_fan_out.Publish("before"))
  process.sleep(50)

  // A subscriber that joins late still misses the live broadcast, same as
  // the plain fan-out - but unlike the plain version, that event wasn't
  // lost. It's sitting in Mnesia and can be replayed on demand.
  let history = persisted_fan_out.events_for(started.pid)
  assert list.contains(history, "before")
}
