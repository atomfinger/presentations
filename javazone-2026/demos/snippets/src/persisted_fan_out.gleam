import gleam/erlang/process.{type Pid, type Subject}
import gleam/list
import gleam/otp/actor

pub type Message(event) {
  Subscribe(subscriber: Subject(event))
  Publish(event: event)
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
  subscribers: List(Subject(event)),
  message: Message(event),
) -> actor.Next(List(Subject(event)), Message(event)) {
  case message {
    Subscribe(subscriber) -> actor.continue([subscriber, ..subscribers])

    Publish(event) -> {
      store_event(process.self(), event)
      list.each(subscribers, fn(subscriber) { process.send(subscriber, event) })
      actor.continue(subscribers)
    }
  }
}
