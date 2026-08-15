import gleam/erlang/process.{type Pid, type Subject}
import gleam/list
import gleam/otp/actor

pub type Message(event) {
  Subscribe(subscriber: Subject(Delivery(event)))
  Publish(event: event)
}

pub type Delivery(event) {
  Deliver(event: event, ack_to: Subject(Ack))
}

pub type Ack {
  Ack
}

@external(erlang, "persisted_fan_out_ffi", "ensure_table")
fn ensure_table() -> Nil

@external(erlang, "persisted_fan_out_ffi", "store_event")
fn store_event(actor_pid: Pid, event: event) -> Nil

@external(erlang, "persisted_fan_out_ffi", "events_for")
pub fn events_for(actor_pid: Pid) -> List(event)

pub fn start() -> actor.StartResult(Subject(Message(event))) {
  ensure_table()

  actor.new([])
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  subscribers: List(Subject(Delivery(event))),
  message: Message(event),
) -> actor.Next(List(Subject(Delivery(event))), Message(event)) {
  case message {
    Subscribe(subscriber) -> actor.continue([subscriber, ..subscribers])

    Publish(event) -> {
      store_event(process.self(), event)
      list.each(subscribers, fn(subscriber) {
        let _ = deliver_with_ack(subscriber, event, retries: 3, timeout_ms: 200)
        Nil
      })
      actor.continue(subscribers)
    }
  }
}

fn deliver_with_ack(
  to subscriber: Subject(Delivery(event)),
  event event: event,
  retries retries: Int,
  timeout_ms timeout_ms: Int,
) -> Result(Nil, Nil) {
  let ack_subject = process.new_subject()
  process.send(subscriber, Deliver(event, ack_subject))

  case process.receive(ack_subject, timeout_ms) {
    Ok(Ack) -> Ok(Nil)
    Error(Nil) ->
      case retries > 0 {
        True -> deliver_with_ack(subscriber, event, retries - 1, timeout_ms)
        False -> Error(Nil)
      }
  }
}
