import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type Message(event) {
  Subscribe(subscriber: Subject(event))
  Publish(event: event)
}

pub fn start() -> actor.StartResult(Subject(Message(event))) {
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
      list.each(subscribers, fn(subscriber) { process.send(subscriber, event) })
      actor.continue(subscribers)
    }
  }
}
