import gleam/erlang/process.{type Pid}

/// The whole "protocol" for this demo: a query with a number, and a reply
/// with the answer. Both the central node and every querying node are
/// running this exact same compiled code, so a `Query` sent from one node
/// arrives on another as the exact same tagged Gleam value - no manual
/// (de)serialisation code anywhere.
pub type Message {
  Query(reply_to: Pid, number: Int)
  Reply(number: Int, result: String)
}
