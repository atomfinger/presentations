import cluster_fizzbuzz/colors
import cluster_fizzbuzz/ffi
import cluster_fizzbuzz/message.{type Message, Query, Reply}
import cluster_fizzbuzz/trace
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io

const server_name = "fizzbuzz_server"

/// A node that knows nothing about fizz-buzz itself - it just asks the
/// central node about a number, over and over, and prints whatever comes
/// back. This is the "client" half of the demo.
///
/// `central_node` is the distributed Erlang node name of the fizzbuzz
/// server (e.g. "central@127.0.0.1").
pub fn run(label: String, central_node: String) -> Nil {
  log(label, "starting up, targeting " <> central_node)
  query_loop(label, central_node, 1)
}

/// Every single iteration re-connects and re-resolves the server's pid,
/// rather than looking it up once and caching it. This is deliberate, not
/// wasteful: distributed Erlang connections don't automatically
/// re-establish themselves after a node goes away, and `global`'s name
/// table only ever reflects whoever is *currently* registered - a cached
/// pid from before a crash would just be a dead pid we keep shouting into.
/// Re-resolving every time is what makes "central comes back with a brand
/// new pid" something this loop recovers from on its own, with no extra
/// coordination.
///
/// The same request number is retried until it actually gets a reply -
/// this loop counts *successful answers*, not *attempts*, so a dead
/// central node pauses progress instead of silently skipping numbers.
fn query_loop(label: String, central_node: String, n: Int) -> Nil {
  case find_server(central_node) {
    Error(Nil) -> {
      log(label, "fizzbuzz server not reachable, retrying...")
      process.sleep(500)
      query_loop(label, central_node, n)
    }

    Ok(server) -> {
      trace.message(
        from: ffi.node_name(),
        to: ffi.pid_node(server),
        label: "query",
        contents: "number=" <> int.to_string(n),
      )
      ffi.raw_send(server, Query(process.self(), n))

      case ffi.raw_receive(2000) {
        Ok(message) -> {
          handle_reply(label, message)
          process.sleep(700)
          query_loop(label, central_node, n + 1)
        }
        Error(Nil) -> {
          log(
            label,
            "no reply for "
              <> int.to_string(n)
              <> " - will retry the same number",
          )
          process.sleep(700)
          query_loop(label, central_node, n)
        }
      }
    }
  }
}

fn find_server(central_node: String) -> Result(process.Pid, Nil) {
  ffi.connect(central_node)
  ffi.global_whereis(atom.create(server_name))
}

fn handle_reply(label: String, message: Message) -> Nil {
  case message {
    Reply(number, result) ->
      log(label, "asked about " <> int.to_string(number) <> " -> " <> result)
    Query(_, _) -> Nil
  }
}

fn log(label: String, text: String) -> Nil {
  io.println(colors.paint("[" <> label <> " @ " <> ffi.node_name() <> "] " <> text, label))
}
