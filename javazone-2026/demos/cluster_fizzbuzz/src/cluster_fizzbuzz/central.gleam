import cluster_fizzbuzz/colors
import cluster_fizzbuzz/ffi
import cluster_fizzbuzz/fizzbuzz
import cluster_fizzbuzz/message.{type Message, Query, Reply}
import cluster_fizzbuzz/trace
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io

const server_name = "fizzbuzz_server"

/// The one process that actually knows fizz-buzz. Every other node in the
/// cluster only ever sends it a number and waits for an answer - the logic
/// itself lives in exactly one place.
pub fn run() -> Nil {
  let name = atom.create(server_name)
  ffi.global_register(name, process.self())

  log(
    "registered cluster-wide as '" <> server_name <> "' - waiting for queries",
  )

  loop()
}

fn loop() -> Nil {
  case ffi.raw_receive(60_000) {
    Ok(message) -> {
      handle(message)
      loop()
    }
    Error(Nil) -> loop()
  }
}

fn handle(message: Message) -> Nil {
  case message {
    Query(reply_to, number) -> {
      let result = fizzbuzz.compute(number)
      log(
        ffi.pid_node(reply_to)
        <> " asked about "
        <> int.to_string(number)
        <> " -> "
        <> result,
      )
      trace.message(
        from: ffi.node_name(),
        to: ffi.pid_node(reply_to),
        label: "reply",
        contents: result,
      )
      ffi.raw_send(reply_to, Reply(number, result))
    }
    Reply(_, _) -> Nil
  }
}

fn log(text: String) -> Nil {
  io.println(colors.paint("[central @ " <> ffi.node_name() <> "] " <> text, "central"))
}
