import cluster_fizzbuzz/central
import cluster_fizzbuzz/ffi
import cluster_fizzbuzz/querier
import gleam/io

pub fn main() -> Nil {
  case ffi.plain_arguments() {
    ["central"] -> central.run()
    ["query", label] -> querier.run(label, "central@127.0.0.1")
    ["query", label, central_node] -> querier.run(label, central_node)
    _ -> usage()
  }
}

fn usage() -> Nil {
  io.println(
    "Start this node with an erl -extra argument to choose a role:\n"
    <> "  ... -extra central                              (computes fizzbuzz)\n"
    <> "  ... -extra query <label> [central-node-name]     (only asks questions)\n"
    <> "\n"
    <> "The central node name defaults to central@127.0.0.1 if not given.",
  )
}
