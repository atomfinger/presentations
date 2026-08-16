import gleam/erlang/atom

/// Reports one event to Erlang/OTP's built-in Event Tracer (`et`) - a
/// standard OTP application, not a dependency we added. `et:trace_me/5` on
/// its own does nothing but return; it only becomes visible once something
/// (an `et_viewer` sequence-chart GUI, in this demo) turns on tracing for
/// this function. That's deliberate: the call site doesn't need to know or
/// care whether anyone is watching.
@external(erlang, "et", "trace_me")
fn raw_trace_me(
  detail_level: Int,
  from: atom.Atom,
  to: atom.Atom,
  label: atom.Atom,
  contents: contents,
) -> Nil

/// Report that a message logically flowed from `from` to `to`.
///
/// `from`/`to`/`label` become Erlang atoms under the hood. This is only
/// safe because this demo only ever calls it with a small, fixed set of
/// node names and event labels - atoms are never garbage collected on the
/// BEAM, so turning arbitrary, unbounded runtime strings (a request ID, a
/// user-supplied value, ...) into atoms in a hot path is a real, separate
/// footgun, not something to copy into production code unchanged.
pub fn message(from from: String, to to: String, label label: String, contents contents: String) -> Nil {
  raw_trace_me(
    100,
    atom.create(from),
    atom.create(to),
    atom.create(label),
    contents,
  )
}
