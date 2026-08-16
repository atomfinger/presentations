# cluster_fizzbuzz

A talk demo for JavaZone 2026 ("Beam and Gleam"). Not a package - a runnable
illustration of distribution as a runtime primitive: real, separate BEAM
nodes, on real distributed Erlang, sending real Gleam-typed messages to each
other across the network.

## What it does

- One node (`central`) owns the entire fizz-buzz logic and registers itself
  cluster-wide under the name `fizzbuzz_server`, using Erlang's built-in
  `global` module (the distributed sibling of node-local process
  registration).
- Any number of other nodes (`node2`, `node3`, ...) know nothing about
  fizz-buzz. They just look up `fizzbuzz_server` in the cluster, send it a
  number, and print back whatever comes over the wire.
- Every node runs the exact same compiled code and shares the same Gleam
  message type (`cluster_fizzbuzz/message.{Query, Reply}`), so a message
  sent on one node arrives as the identical typed Gleam value on another -
  there's no manual serialisation anywhere in this demo.
- Each node's output is colour-coded - `central` is always green, every
  other label gets a colour picked deterministically from a fixed palette
  (`src/cluster_fizzbuzz/colors.gleam`), so this scales from two or three
  hand-narrated nodes up to a swarm of twenty without needing a colour
  assigned per label.

## Why it drops to raw Erlang primitives in a couple of places

Gleam's own `gleam_otp`/`gleam_erlang` `Name`/`Subject` abstraction is
designed for processes that are already part of one supervision tree on one
node - it doesn't have a built-in story for "a process on a completely
separate, independently-started node wants to address me by name." That's
exactly what Erlang's `global` module is for, so this demo uses a handful
of tiny FFI bindings (`src/cluster_fizzbuzz_ffi.erl` +
`src/cluster_fizzbuzz/ffi.gleam`) onto `global:register_name/2`,
`global:whereis_name/1`, and a plain untyped `!`/`receive`. This is worth
saying out loud on stage: this is intentionally the same raw, untyped
mailbox layer that Gleam usually protects you from - here we've dropped down
to it on purpose, for the cluster-wiring seam specifically, then wrapped the
result straight back into typed Gleam messages for everything else.

## Running it

You need at least two terminals (three is more convincing).

**Terminal 1 - the central node:**

```sh
scripts/run-central.sh
```

**Terminal 2 - a querying node:**

```sh
scripts/run-node.sh node2
```

**Terminal 3 - another querying node (optional but recommended):**

```sh
scripts/run-node.sh node3
```

You should see `node2`/`node3`'s terminals printing a steady stream of
`asked about N -> <fizz/buzz/number>`, and the central terminal printing
the same queries with the asking node's name attached - proof the number
crossed a real network hop and the answer came straight back.

All three talk to each other over `epmd` (the Erlang Port Mapper Daemon)
and a shared cookie (`javazone_demo` by default) - the same two mechanisms
described in the talk script.

### Scaling it up: a swarm of nodes

Three nodes narrated by hand makes the mechanism clear. Twenty nodes,
started all at once and left running unattended, makes the scale argument
instead - the same lookup-and-message mechanism, with no per-node ceremony,
whether it's one querying node or dozens.

```sh
scripts/run-swarm.sh 20
```

This starts 20 more nodes (`swarm1`...`swarm20`, kept distinct from the
`node2`/`node3` you narrate by hand), each independently finding and
querying the same central node. They log to `logs/swarmN.log` instead of
the terminal - twenty scrolling terminal windows is not a demo. Point
`scripts/observe.sh`'s "Nodes" tab or `scripts/et-viewer.sh`'s diagram at
it afterwards to show all ~21 nodes connected and talking at once. Stop
them all with:

```sh
scripts/stop-swarm.sh
```

Tested locally with 20: all connect and start querying within a couple of
seconds, and shut down cleanly. The count is a plain argument
(`run-swarm.sh 50` works the same way) if you want to push it further, but
20 is already enough to make the point without turning into its own
science project on stage.

### The "kill a node" moment

While it's running, kill one of the query node terminals (Ctrl+C, or `kill`
the process from another terminal). The central node and any remaining
query nodes keep running, completely unaffected - nobody needed to notice
or clean up after the dead node. This is deliberately the lead-in to the
"Let it crash" section of the talk: the same philosophy, one level up, at
the scale of an entire node instead of a single process.

### Killing *central* instead - and bringing it back

This is the more interesting failure to demo, and it's worth doing
deliberately rather than only killing a query node:

```sh
# find its pid, e.g. via `ps aux | grep central@127.0.0.1`, then:
kill <central's pid>
```

Every query node's terminal will start printing
`fizzbuzz server not reachable, retrying...` - and it will keep retrying
the *exact same request number* the whole time central is down, not
counting upward through numbers nobody answered. Then bring central back:

```sh
scripts/run-central.sh
```

The query nodes reconnect and resume from that same number on their own -
no restart, no manual reconnect, no shared state carried over from the old
central process (it's a brand new pid; central doesn't remember anything
about the old one). This is the same "distributed nodes connect lazily,
and `global`'s registrations track whoever is *currently* there" mechanism
from earlier in the talk, just demonstrated as an actual recovery instead
of only described.

Both halves of this were bugs in an earlier version of this demo, worth
knowing about if you're reading the source: the query loop used to resolve
central's pid *once* and cache it, so after a restart it kept addressing a
dead pid forever and never noticed the new one; and it incremented its
request counter on every attempt rather than only on a successful reply,
so "central was down for 5 seconds" silently looked like "5 numbers came
back that were never actually asked about." `query_loop` in
`src/cluster_fizzbuzz/querier.gleam` now re-resolves the server's pid on
every iteration and only advances the counter once a reply actually
arrives.

### Watching it with `:observer`

```sh
scripts/observe.sh
```

This opens Erlang/OTP's built-in `:observer` GUI, connected into the
cluster. Open the "Nodes" tab to see all connected nodes live, and watch a
node disappear from that list the moment you kill it.

**Rehearse this specific part ahead of time.** `:observer` needs `wx` (GUI
bindings) present in the local Erlang/OTP build - not guaranteed on every
install - and it's a GUI window you have to keep alive and visible during a
live talk, which is its own category of demo risk. Have a screenshot as a
fallback.

### Watching it with `et_viewer` (the sequence-diagram view)

Every query and reply in this demo is also reported via Erlang/OTP's
built-in Event Tracer (`et:trace_me/5` - a standard OTP application, not a
dependency we added). See `src/cluster_fizzbuzz/trace.gleam` for the two
call sites (one on the querying side, one on the central side - one
`trace_me` call per logical hop, not one per node, so the diagram doesn't
show duplicate arrows).

```sh
scripts/et-viewer.sh
```

This opens `et_viewer`, which renders those events live as an actual
sequence diagram: one column per node, a line drawn across the diagram
every time a query or reply crosses between them. This is the closest
thing in the ecosystem to a literal "draw a line when a message is sent"
visualisation, and it's genuinely wired up here, not just described.

**Two important notes, both learned the hard way while wiring this up:**

- `et_viewer:start()` with no arguments is *not* enough on its own.
  `et_collector`'s `trace_pattern` option defaults to `undefined`, which
  traces nothing at all regardless of whether global tracing is on. This
  demo's script passes `{trace_global, true}` and
  `{trace_pattern, {et, max}}` explicitly - confirmed by hand, headlessly
  (via `et_collector` directly, capturing real cross-node events into its
  table) - before ever touching the GUI.
- The GUI rendering itself was **not** visually verified in the environment
  this was built in (no display available). The underlying event capture
  was confirmed working end-to-end across three real nodes; whether the
  sequence-diagram window itself looks right is worth a quick check on
  your actual machine before relying on it live. It also needs `wx` (GUI
  bindings) present in the local Erlang/OTP build, same caveat as
  `:observer` below.

Treat this as a genuine second live view alongside the colour-coded
terminal output, not a replacement for it - the terminal output has no GUI
dependency and is the one to fall back on if `et_viewer` doesn't cooperate
on stage.

#### If the window shows up blank

`scripts/et-viewer.sh` now prints its own diagnostics straight to the
terminal - `connect_node` result, the node list, the collector pid, and
the event count after 2s and 5s - specifically so a blank window doesn't
leave you guessing. Read those lines first:

- **Event count stays at 0.** Tracing genuinely isn't capturing anything.
  Double-check `run-central.sh` and at least one `run-node.sh`/`run-swarm.sh`
  are actually running and actively querying (check their own log
  output), and that `COOKIE`/`NODE_HOST` match what they were started
  with. One concrete bug this already caught once: an earlier version of
  this script omitted `-noshell` - without it, in a non-interactive
  terminal, the diagnostic `io:format` output can get buffered and never
  flushed, which looks exactly like "nothing is happening" even when
  tracing is working fine underneath. If you're editing this script
  further, keep `-noshell`.
- **Event count is climbing (>0 and increasing between the two prints)
  but the window still looks empty.** Tracing is genuinely working - this
  is now a rendering/display problem, not a tracing one. Things worth
  trying: give it a few more seconds (the chart draws as events arrive, it
  doesn't backfill instantly), check the actor/column list in the window
  actually shows the node names you expect (this script sets
  `max_actors: 30` so a swarm run shouldn't get truncated), and try the
  window's own zoom/scale controls - at the default scale, a chart with
  only 2-3 actors clustered close together can look sparser than expected
  until you zoom in.
- **The script errors before printing anything.** Almost always `wx` isn't
  present in the local Erlang/OTP build - check with
  `erl -noshell -eval 'io:format("~p~n",[code:which(wx)]), halt().'`
  ahead of time, not on stage.

## Configuration

All of the scripts (`run-central.sh`, `run-node.sh`, `run-swarm.sh`,
`observe.sh`, `et-viewer.sh`) read the same environment variables if you
need to change anything:

- `NODE_HOST` (default `127.0.0.1`) - the host part of every node's name.
- `COOKIE` (default `javazone_demo`) - the shared magic cookie.
- `CENTRAL_NODE` (used by `run-node.sh`/`observe.sh`/`et-viewer.sh`, default
  `central@$NODE_HOST`) - only needed if the central node isn't using the
  default host.

## Development

```sh
gleam build  # Compile
gleam test   # Run the (minimal) tests
```
