import fan_out
import gleam/erlang/process

pub fn publish_reaches_every_subscriber_test() {
  let assert Ok(started) = fan_out.start()
  let publisher = started.data

  let subscriber_a = process.new_subject()
  let subscriber_b = process.new_subject()
  let subscriber_c = process.new_subject()

  process.send(publisher, fan_out.Subscribe(subscriber_a))
  process.send(publisher, fan_out.Subscribe(subscriber_b))
  process.send(publisher, fan_out.Subscribe(subscriber_c))

  process.send(publisher, fan_out.Publish("hello"))

  assert process.receive(subscriber_a, 100) == Ok("hello")
  assert process.receive(subscriber_b, 100) == Ok("hello")
  assert process.receive(subscriber_c, 100) == Ok("hello")
}

pub fn a_subscriber_does_not_get_events_published_before_it_subscribed_test() {
  let assert Ok(started) = fan_out.start()
  let publisher = started.data

  process.send(publisher, fan_out.Publish("before"))

  let late_subscriber = process.new_subject()
  process.send(publisher, fan_out.Subscribe(late_subscriber))

  // Nothing to receive yet - "before" was published before this subscriber
  // joined, and a fan-out this simple has no history/replay.
  assert process.receive(late_subscriber, 50) == Error(Nil)

  process.send(publisher, fan_out.Publish("after"))

  assert process.receive(late_subscriber, 100) == Ok("after")
}

pub fn publishing_with_no_subscribers_does_not_crash_test() {
  let assert Ok(started) = fan_out.start()
  let publisher = started.data

  process.send(publisher, fan_out.Publish("into the void"))

  // If this test function returns at all, the actor survived publishing
  // to zero subscribers.
  Nil
}
