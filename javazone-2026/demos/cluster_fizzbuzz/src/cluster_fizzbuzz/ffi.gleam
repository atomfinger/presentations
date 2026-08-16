import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Pid}

/// Thin bindings onto plain Erlang/OTP primitives that Gleam's higher-level
/// `gleam_erlang`/`gleam_otp` APIs don't expose directly - because they are
/// specifically the *untyped*, cluster-wide, "any node can reach any pid"
/// layer underneath everything else in this talk. We drop down to it here
/// on purpose, for exactly the cluster-wiring part of the demo.

/// `global` is Erlang's cluster-wide name registry - the distributed
/// sibling of the node-local `erlang:register/2`.
@external(erlang, "cluster_fizzbuzz_ffi", "global_register")
pub fn global_register(name: Atom, pid: Pid) -> Nil

@external(erlang, "cluster_fizzbuzz_ffi", "global_whereis")
pub fn global_whereis(name: Atom) -> Result(Pid, Nil)

/// A plain, untyped `!` send and a plain mailbox `receive` - the same raw
/// primitives every BEAM language, including Gleam, is ultimately built on.
@external(erlang, "cluster_fizzbuzz_ffi", "raw_send")
pub fn raw_send(pid: Pid, msg: message) -> Nil

@external(erlang, "cluster_fizzbuzz_ffi", "raw_receive")
pub fn raw_receive(timeout_ms: Int) -> Result(message, Nil)

@external(erlang, "cluster_fizzbuzz_ffi", "plain_arguments")
pub fn plain_arguments() -> List(String)

@external(erlang, "cluster_fizzbuzz_ffi", "node_name")
pub fn node_name() -> String

@external(erlang, "cluster_fizzbuzz_ffi", "pid_node")
pub fn pid_node(pid: Pid) -> String

@external(erlang, "cluster_fizzbuzz_ffi", "connect")
pub fn connect(node_name: String) -> Nil
