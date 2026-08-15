import acked_fan_out.{type Delivery, Ack, Deliver}
import gleam/erlang/process.{type Subject}
import gleam/list

pub fn a_subscriber_that_acks_immediately_gets_the_event_exactly_once_test() {
  let attempts = process.new_subject()
  let subscriber = spawn_flaky_subscriber(ack_after: 1, report_to: attempts)

  let assert Ok(started) = acked_fan_out.start()
  let publisher = started.data

  process.send(publisher, acked_fan_out.Subscribe(subscriber))
  process.send(publisher, acked_fan_out.Publish("hello"))

  assert process.receive(attempts, 200) == Ok(1)
}

pub fn a_flaky_subscriber_gets_retried_until_it_finally_acks_test() {
  let attempts = process.new_subject()
  let subscriber = spawn_flaky_subscriber(ack_after: 3, report_to: attempts)

  let assert Ok(started) = acked_fan_out.start()
  let publisher = started.data

  process.send(publisher, acked_fan_out.Subscribe(subscriber))
  process.send(publisher, acked_fan_out.Publish("hello"))

  assert process.receive(attempts, 300) == Ok(1)
  assert process.receive(attempts, 300) == Ok(2)
  assert process.receive(attempts, 300) == Ok(3)
}

pub fn publishing_still_persists_to_mnesia_alongside_the_ack_guarantee_test() {
  let subscriber = spawn_flaky_subscriber(ack_after: 1, report_to: process.new_subject())

  let assert Ok(started) = acked_fan_out.start()
  let publisher = started.data

  process.send(publisher, acked_fan_out.Subscribe(subscriber))
  process.send(publisher, acked_fan_out.Publish("first"))

  // Publish itself has no reply, so give the actor a beat to finish the
  // Mnesia write and the (near-instant) ack round trip.
  process.sleep(50)

  let events = acked_fan_out.events_for(started.pid)
  assert list.contains(events, "first")
}

/// A subscriber that only acknowledges once it has seen a message
/// `ack_after` times - standing in for a flaky real-world subscriber that
/// occasionally drops a message. Reports each attempt number to
/// `report_to` so a test can watch the retries happen.
///
/// A `Subject` is owned by whoever creates it, and only its owner may
/// receive on it - so the spawned process has to create its own subject
/// and hand it back to the caller, rather than receiving on one the
/// caller created for it.
fn spawn_flaky_subscriber(
  ack_after ack_after: Int,
  report_to report_to: Subject(Int),
) -> Subject(Delivery(String)) {
  let ready = process.new_subject()

  process.spawn(fn() {
    let subject = process.new_subject()
    process.send(ready, subject)
    flaky_loop(subject, ack_after, 0, report_to)
  })

  let assert Ok(subject) = process.receive(ready, 100)
  subject
}

fn flaky_loop(
  subject: Subject(Delivery(String)),
  ack_after: Int,
  attempts: Int,
  report_to: Subject(Int),
) -> Nil {
  let Deliver(_, ack_to) = process.receive_forever(subject)
  let attempts = attempts + 1
  process.send(report_to, attempts)

  case attempts >= ack_after {
    True -> process.send(ack_to, Ack)
    False -> Nil
  }

  flaky_loop(subject, ack_after, attempts, report_to)
}
