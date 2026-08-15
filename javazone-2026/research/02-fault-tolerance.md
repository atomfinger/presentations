# Fault Tolerance on the BEAM

## TL;DR

The BEAM's fault-tolerance story is built on one idea: **a process that hits an error it
cannot handle should crash cleanly, and a separate, simpler, trusted process should detect
that and restart it from a known-good state.** This is the "let it crash" / "do not program
defensively" philosophy from Joe Armstrong's 2003 PhD thesis. It is *safe* on the BEAM only
because of **process isolation** — each process has its own heap and shares nothing, so one
crashing process cannot corrupt another's state — and it is *organized* by **supervision
trees** built from OTP behaviours (`gen_server`, `supervisor`). The crucial mental shift for
JVM developers: error recovery is not `try/catch` woven through your business logic; it is a
*structural* property of the system, pushed out to dedicated supervisors that observe workers
and restart them. The honest caveat, from Armstrong's own case study, is that this is not
magic — it handles *transient* faults well and **"cascading restarts do not work"** for
deeper problems; "let it crash" also assumes you *do* validate inputs at boundaries.

## Key facts & mechanics

### Where "let it crash" comes from

The canonical primary source is **Joe Armstrong, *Making reliable distributed systems in the
presence of software errors*, PhD thesis, Royal Institute of Technology (KTH), Stockholm,
December 2003** (final corrected version, 20 November 2003). The work summarizes a research
program at Ericsson that started in 1981 and produced the Erlang language and the OTP
libraries.

In **Section 4.3 ("Error handling philosophy")** Armstrong states the philosophy as four
slogans (verbatim):

- *Let some other process do the error recovery.*
- *If you can't do what you want to do, die.*
- *Let it crash.*
- *Do not program defensively.*

The reasoning behind "let it crash" (Section 4.4) rests on a distinction Armstrong draws
between exceptions and errors:

- *"exceptions occur when the run-time system does not know what to do."*
- *"errors occur when the programmer doesn't know what to do."*

If the specification does not say what to do in some case, the programmer cannot write
sensible code for it — *"All you can do is terminate the program."* Writing a defensive
catch-all clause that invents behaviour the spec never defined just *"detracts from the pure
case and confuses the reader — the diagnostic is often no better than the diagnostic which
the compiler supplies automatically."* So you write only the "happy path" the spec describes,
and let the runtime crash the process on anything else.

### Why it works on the BEAM specifically: process isolation

"Let it crash" is reckless on a shared-memory runtime and safe on the BEAM. The reason is
*strong process isolation*. In the thesis Armstrong lists six properties of a
"Concurrency Oriented" language (Section 2.4.2); the load-bearing ones for fault tolerance:

- *"Several processes operating on the same machine must be strongly isolated. A fault in one
  process should not adversely effect another process, unless such interaction is explicitly
  programmed."*
- *"There should be no shared state between processes. Processes interact by sending
  messages."*

Mechanically, on the BEAM this is real, not aspirational:

- Each process has its **own private heap and stack**; there is **no shared mutable memory**
  between processes. Data sent in a message is *copied* into the receiver's heap, so the
  receiver cannot hold a pointer into the sender's memory. (See companion doc
  `03-concurrency.md` and the Erlang GC docs.)
- Because heaps are separate, **garbage collection is per-process** and, more importantly
  here, **a corrupted or half-updated heap in one process is invisible to every other
  process.** When a process dies, its heap is simply reclaimed.

Armstrong's framing (Section 2.4.3): two processes on the same machine *"must be as
independent as if they ran on physically separated machines."* The consequence he draws is
explicit: the only realistic way to build large reliable systems is *"by partitioning the
system into independent parallel processes, and by providing mechanisms for monitoring and
restarting these processes."* Contrast with shared-memory threading, which he calls out
directly: *"The commonly used threads model of programming, where resources are shared, makes
it extremely difficult to isolate components from each other — errors in one component can
propagate to another component and damage the internal consistency of the system."*

### The error-kernel pattern: keep a small trusted core correct

Armstrong's strategy (Chapter 5) is a *hierarchy of tasks*: *"if we cannot do what we want to
do, then try to do something simpler."* As you descend the hierarchy, *"the likelihood of
success increases as the tasks become simpler"* and the emphasis shifts from full service to
*"protecting the system against damage."*

This is the **error-kernel** idea, usually stated as: keep a *small, simple, trusted core*
that you can argue is correct, and push *risky, complex work* out to *restartable workers*
below it. In Armstrong's worker/supervisor split (Section 4.3.2):

- *"One process, the worker process, does the job. Another process, the supervisor process,
  observes the worker. If an error occurs in the worker, the supervisor takes actions to
  correct the error."*
- The win: *"There is a clean separation of issues. The processes that are supposed to do
  things (the workers) do not have to worry about error handling."* Error-correcting code is
  often *generic* (reusable across applications) while worker code is application-specific.

The practical heuristic from the AXD301 case study (below) reinforces this: keep the trusted
part *small and flat*, because the deeper and more elaborate your recovery logic, the less
likely it is to actually work.

### Links vs monitors: how failure propagates

The BEAM gives processes two primitives for observing each other's death. They are the raw
material supervisors are built from.

**Links (`link/1`, `spawn_link`)** — *bidirectional*:

- *"Links are bidirectional and there can only be one link between two processes."* Linking
  is idempotent (calling `link/1` repeatedly creates one link, not a stack).
- When a process terminates abnormally, it sends an **exit signal** to everything it is
  linked to. By default, a linked process that receives an exit signal with a reason *other
  than* `normal` **also terminates** — failure cascades along links. This is how a crash
  "spreads" to a group that should live or die together.
- Special reasons: an exit signal with reason **`normal`** is *"silently dropped"* if the
  receiver is not trapping exits (normal termination does not kill your linked peers). The
  reason **`kill`** is special: *"the receiver cannot trap the exit signal and will
  unconditionally terminate,"* terminating with reason **`killed`** — this is the
  unstoppable "brutal kill" used to force shutdown.

**Trapping exits (`process_flag(trap_exit, true)`)** — turns a process into a *system
process*: incoming exit signals are *"converted to a message signal and added to the end of
the message queue"* as `{'EXIT', FromPid, Reason}` instead of killing the receiver. This is
exactly how a **supervisor** stays alive when its children die — it traps exits, so a child's
death arrives as a message it can act on rather than a signal that kills it.

**Monitors (`monitor/2`, `spawn_monitor`)** — *unidirectional and stackable*:

- Only the monitoring process is notified; the monitored process is unaffected by the
  monitor.
- On termination the monitor receives `{'DOWN', Ref, process, Pid, Reason}` (and immediately
  with `Reason = noproc` if the target was already dead).
- Multiple independent monitors can exist and be removed individually (`demonitor`).

Rule of thumb: **links** express *"these processes share a fate"* (the structural/supervision
relationship); **monitors** express *"I want to know if that process dies, but I'm not tied to
it"* (the observational relationship used by libraries and clients, e.g. inside `gen_server`
calls).

How a crash actually propagates upward (thesis Section 5.1): the VM detects a low-level fault
(divide-by-zero, no matching clause) and *throws an exception*; if no `catch` handles it the
*process fails*; the failure reason is *"propagated to any processes which are currently
linked to the process which has failed"*; a linked supervisor (trapping exits) receives it
and runs recovery. *"What starts off as an abnormal condition in the virtual machine emulator
propagates upwards in the system."*

### Supervisors, supervision trees, and OTP behaviours

**OTP behaviours** are generic, battle-tested process skeletons; you supply only the
callbacks. The two central ones for fault tolerance:

- **`gen_server`** — the generic client/server. You implement callbacks: `init/1`,
  `handle_call/3` (synchronous request → `{reply, Reply, State}`), `handle_cast/2`
  (asynchronous → `{noreply, State}`), `handle_info/2` (other messages), `terminate/2`, and
  `code_change/3`. *"If the gen_server is part of a supervision tree, no stop function is
  needed. The gen_server is automatically terminated by its supervisor."* The behaviour
  handles the concurrency, message-loop, and OTP plumbing; your callback module is essentially
  sequential code.
- **`supervisor`** — a process whose only job is to start, monitor, and restart its children.
  *"A supervisor is responsible for starting, stopping, and monitoring its child processes."*
  Children are either **workers** (e.g. `gen_server`s) or **other supervisors** — nesting
  supervisors yields a **supervision tree**. Armstrong: *"Supervision trees are hierarchical
  trees of supervisors. Each node in the tree is responsible for monitoring errors in its
  child nodes."*

**Restart strategies** (OTP `supervisor`, identical in Erlang and Elixir):

- **`one_for_one`** — *"If a child process terminates, only that process is restarted."* The
  default; use when children are independent.
- **`one_for_all`** — *"If a child process terminates, all remaining child processes are
  terminated [and] then all child processes, including the terminated one, are restarted."*
  Use when children are interdependent and must share fate.
- **`rest_for_one`** — *"If a child process terminates, the child processes after the
  terminated process in start order are terminated. Subsequently, the terminated child process
  and the remaining child processes are restarted."* Use when later children depend on earlier
  ones.
- **`simple_one_for_one`** — a variant for a large, dynamically growing set of identical
  children (e.g. one worker per connection); children are added at runtime via
  `supervisor:start_child/2`. **In Elixir this is deprecated in favour of `DynamicSupervisor`**
  (introduced in Elixir 1.6), which starts with no children and takes the child spec at
  `start_child/2` time.

(Armstrong's thesis describes the conceptual model as **AND** supervision — *"if any child
dies … stop all my children and restart all my children"* — and **OR** supervision —
*"restart [only] the child that died."* In shipped OTP these map onto `one_for_all` and
`one_for_one` respectively.)

**Child restart types** — *per child*, orthogonal to the strategy:

- **`permanent`** — *"always restarted."*
- **`transient`** — *"restarted only if it terminates abnormally,"* i.e. with a reason other
  than `normal`, `shutdown`, or `{shutdown, Term}`.
- **`temporary`** — *"never restarted"* (not even when a sibling's death would otherwise take
  it down under `one_for_all`/`rest_for_one`).

**Restart intensity / max restarts** — the circuit breaker that stops restart loops. The
supervisor flags `intensity` (a.k.a. `max_restarts`) and `period` (`max_seconds`) mean: *"If
more than `MaxR` restarts occur in the last `MaxT` seconds, the supervisor terminates all the
child processes and then itself"* (with reason `shutdown`, which then propagates the failure
up to *its* supervisor). Defaults differ by ecosystem:

- **Erlang OTP `supervisor`**: `intensity` defaults to **1**, `period` to **5** seconds.
- **Elixir `Supervisor`**: `max_restarts` defaults to **3**, `max_seconds` to **5**.

The point of giving up: if restarting hasn't fixed it within the budget, the fault is not
transient, so escalate to the next level up rather than spin forever.

### How this differs from JVM exception handling and thread crashes

| | BEAM | JVM (classic threads) |
|---|---|---|
| Unit of failure | Isolated process with private heap | Thread sharing the process heap |
| State on crash | Discarded; restarted clean from `init` | Shared mutable objects may be left half-updated |
| Default recovery | Structural — supervisor restarts the unit | None automatic; a thread dies, its work is lost |
| Error-handling style | "Happy path" + crash; recovery is elsewhere | Defensive `try/catch` interleaved with logic |
| Cross-component blast radius | Contained by isolation + copying | Corrupted shared state can poison other threads |

Concretely:

- **A crashed JVM thread does not restart a clean, isolated unit of state.** An uncaught
  exception propagates up that thread's stack; if unhandled it reaches the thread's
  `UncaughtExceptionHandler` and the thread simply *dies*. The JVM does not restart it, and
  any mutable objects it shared with other threads remain in whatever (possibly inconsistent)
  state it left them. There is no built-in "restart this subsystem from a known-good state."
- **Shared mutable heap.** JVM threads share one heap, so a bug in one thread can corrupt data
  another thread relies on — exactly the propagation Armstrong warns about. The BEAM's
  share-nothing + copy-on-send design makes that class of corruption structurally impossible.
- **Defensive style.** Idiomatic Java wraps risky operations in `try/catch` *in the same
  thread of control* as the business logic. Armstrong's contrast (Section 4.3): *"In a
  sequential language with exceptions, the programmer encloses any code that is likely to fail
  within an exception handling construct and tries to contain all errors that can occur within
  this construct."* On the BEAM the error-handling code and the failing code run in
  *different processes*, so *"the code which solves the problem is not cluttered up with the
  code which handles the exception."*

Note the convergence caveat for honesty: modern JVM patterns (thread pools that replace dead
workers, actor frameworks like **Akka/Pekko** that *deliberately* port supervision and "let it
crash" to the JVM, and circuit breakers) close part of the gap. The difference is that on the
BEAM isolation + supervision are *the runtime's native model*, not a library bolted on top of
a shared-memory runtime.

## Numbers & benchmarks

Real, citable figures — almost all from the thesis's own case studies (Chapter 8). These are
"existence proof" numbers, not modern benchmarks.

- **AXD301 ATM switch (Ericsson), the flagship case study:** *"over 1.7 million lines of
  Erlang code"* at time of writing (2003) — *"probably the largest system ever to be written
  in a functional style of programming."*
- **AXD301 supervision tree:** **141 nodes**, using **191 instances** of OTP behaviours,
  broken down as `gen_server` **(122)**, `gen_event` **(36)**, `supervisor` **(20)**,
  `gen_fsm` **(10)**, `application` **(6)**. **63%** of all generic objects in the system were
  client-servers (`gen_server`) — evidence of how few behaviours a huge system actually needs.
- **AXD301 sizing:** up to **~50,000 connections per node**; dimensioned for a maximum of
  **120 calls/second** (in setup/termination); call setup uses **six processes per call**,
  reduced afterward to a **~1 KB** call record.
- **Bluetail Mail Robustifier (BMR):** **108 Erlang modules, 36,285 lines of Erlang**, written
  from scratch and delivered within six months; *"in live operation with the Swedish
  Telenordia ISP since 1999"* handling *"millions of emails per year."* Stated reliability
  requirement: *"Down times should be a few minutes per decade."*
- **Documented real recovery events (trouble reports):** HD90439 and HD29758 are real Ericsson
  trouble-report log extracts in the thesis showing the runtime detecting a `function_clause`
  / `case_clause` error and recovering with *"no obvious negative effects on traffic
  handling"* — i.e. "let it crash" actually working in production.

### On the famous "nine nines" (99.9999999%) figure

You will see the claim that the AXD301 achieved **nine nines** of availability. **Treat this
carefully and source it honestly:**

- It does **not** appear as a verified measurement in Armstrong's *thesis*. The thesis's own
  quantitative chapter does not state a nine-nines uptime number; the long-running-stability
  evidence it offers is the qualitative trouble-report analysis above.
- The "nine nines" figure traces to Armstrong's later *talks/slides* and is widely repeated
  second-hand. Armstrong himself characterized it as coming from a customer's PowerPoint
  reporting an 11-node system, and treated it as an uncertain, hard-to-independently-verify
  number. **If you use it on stage, attribute it as an oft-quoted industry claim, not a
  rigorously audited benchmark.**

## Nuance & caveats

- **"Let it crash" is NOT "no error handling."** It means: don't write speculative defensive
  code for situations the spec never defined; *do* write a "well-behaved function" that
  faithfully implements the spec and crashes on the rest. Armstrong's rules for well-behaved
  functions (Section 5.3.1): *Rule 1 — the program should be isomorphic to the specification;
  Rule 2 — if the specification doesn't say what to do, raise an exception; Rule 3 — if the
  exception doesn't carry enough info to isolate the error, add more.* You still validate input
  at trust boundaries, still handle *expected* conditions (a missing file you chose to treat as
  normal is *not* an error), and you crash on the genuinely unexpected.
- **It assumes recoverable/transient faults.** The model leans on the empirical observation
  (Jim Gray, 1985, quoted in the thesis) that *"most production faults are soft. If the program
  state is reinitialized and the failed operation retried, the operation will usually not fail
  the second time."* Restart fixes Heisenbugs, corrupted transient state, and stuck processes.
  It does **not** fix a deterministic bug that crashes on every restart — that just trips the
  restart-intensity limit and escalates.
- **"Cascading restarts do not work."** This is the most important honesty point and it comes
  straight from the case study. Ulf Wiger (chief software architect of the AXD301) found that
  *restarting a failed process with the same arguments often worked, but that if the simple
  restart procedure failed, then cascading restarts (restarting the level above) generally did
  not help.* Consequently the real AXD301 supervision trees were *"very flat … flat rather than
  deep."* Lesson for design: shallow trees, restart at the smallest scope that fixes it, don't
  expect deep restart cascades to rescue you.
- **The "try something simpler" model was only partially used in practice.** Armstrong is
  candid that the full generality of "fall back to a simpler task on failure" was *"only
  partially exploited"* in the AXD301 — much of the resilience came from OTP library services
  (sockets/files auto-closed when their controlling process dies) rather than elaborate
  graceful-degradation logic the application authors wrote.
- **What it does NOT solve:** correctness bugs in the trusted kernel itself (a supervisor or a
  bug in shared protocol code still brings things down); data loss for in-flight work in the
  crashed process (state since the last checkpoint/known-good init is gone unless you persisted
  it — the AXD replicated call state to a backup node precisely for this); deterministic logic
  errors; and cross-node guarantees (message passing is *"send and pray"* — Armstrong's term —
  with no delivery guarantee, so you still design for lost messages). Fault tolerance also does
  not imply *consistency* — a restarted process forgets uncommitted state by design.
- **Definitions matter.** Armstrong defines an error as *"a deviation between the observed
  behaviour of a system and the desired behaviour,"* and adopts the systems definition that *"a
  component is considered faulty once its behaviour is no longer consistent with its
  specification"* (Schneider, 1990). A handled/foreseen exception is *not* a fault. So "is this
  an error?" is a *specification* question, decided by the programmer marking which functions
  must never raise.

## Why it matters for the talk / what JVM folks can learn

The angle for a JVM/Java audience building modest-scale software:

- **Reframe error handling from "catch everywhere" to "isolate and restart."** Most JVM code
  treats failure as something you must anticipate and contain *inline*. The BEAM treats failure
  as *normal and expected* and contains it *structurally*. Even if you never write Erlang/Gleam,
  the design idea — small trusted kernel, restartable workers, supervised lifecycles — is
  portable (it's literally what Akka/Pekko bring to the JVM).
- **The reason it works is the part Java can't easily copy: isolation.** "Let it crash" on a
  shared-mutable heap is dangerous, because a half-finished crashed unit can leave shared
  objects corrupt. On the BEAM, share-nothing + copy-on-send means a crash is *clean* — there
  is nothing shared to corrupt. This is the single most important sentence for the audience:
  **"Let it crash" is only safe because nothing is shared.**
- **Supervision is a first-class, declarative artifact.** You describe your tree — strategy,
  restart types, intensity — and the runtime enforces it. Compare to ad-hoc thread pools and
  scattered retry logic on the JVM. A supervision tree *is* your fault-recovery design,
  written down.
- **Gleam's twist: the same fault tolerance, but *type-checked*.** The mechanics above are
  language-agnostic (BEAM/OTP), and Gleam exposes them through **`gleam_otp`** — typed actors
  and supervisors. Unlike Erlang's `gen_server` or Elixir's `GenServer`, "each message is
  explicitly typed and traceable," so the compiler rejects a malformed message *before* it ever
  reaches a process's mailbox. That's the talk's headline marriage: **"let it crash" resilience
  *plus* compile-time message safety** — fault tolerance without giving up static types.
  (`gleam_otp`: <https://hexdocs.pm/gleam_otp/>.)

**Quotable talking points (all sourceable):**

- *"Let some other process do the error recovery."* / *"If you can't do what you want to do,
  die."* / *"Let it crash."* / *"Do not program defensively."* — Armstrong's four slogans, the
  whole philosophy in nine words. (Thesis §4.3)
- *"Errors occur when the programmer doesn't know what to do."* — the cleanest definition of
  what you should actually crash on. (Thesis §4.4)
- *"A fault in one process should not adversely effect another process, unless such interaction
  is explicitly programmed."* — isolation as a language guarantee. (Thesis §2.4.2)
- *"The commonly used threads model of programming, where resources are shared, makes it
  extremely difficult to isolate components from each other."* — the direct JVM-style contrast,
  in Armstrong's own words. (Thesis §1, intro)
- **"Cascading restarts do not work."** — the honest, memorable caveat; deep recovery trees are
  a trap, keep them flat. (Thesis §8.3, citing Wiger)
- The supervision vocabulary in one breath: *workers do the work, supervisors restart them,
  `one_for_one` / `one_for_all` / `rest_for_one` decide who else goes down with a crash, and
  restart intensity is the circuit breaker that escalates instead of looping.*

## Sources

Primary:

- [Joe Armstrong — *Making reliable distributed systems in the presence of software errors* (PhD thesis, KTH, Dec 2003), official PDF, erlang.org](http://erlang.org/download/armstrong_thesis_2003.pdf) — **the** primary source. Read directly: §1 (intro / threads-model critique), §2.4 (Concurrency Oriented Programming, the six properties, process isolation, message passing), §2.5 (system requirements R1–R6, incl. R2 *error encapsulation*), §4.3–4.4 (error-handling philosophy, the four slogans, "let it crash," workers vs supervisors), §5.1–5.3 (fault-tolerance strategy, supervision hierarchies, AND/OR supervision, definition of error, well-behaved functions), §8.3 (AXD301 quantitative properties, behaviour counts, trouble reports HD90439/HD29758, "cascading restarts do not work," Gray's transient-fault conjecture), §8.4 (Bluetail Mail Robustifier numbers).
- [Supervisor Behaviour — Erlang/OTP System Documentation (erlang.org)](https://www.erlang.org/doc/system/sup_princ.html) — restart strategies (`one_for_one`, `one_for_all`, `rest_for_one`, `simple_one_for_one`), restart intensity (`intensity`/`period`, defaults 1 and 5), child restart types (`permanent`/`transient`/`temporary`), worker vs supervisor, supervision tree definition.
- [gen_server Behaviour — Erlang/OTP System Documentation (erlang.org)](https://www.erlang.org/doc/system/gen_server_concepts.html) — `gen_server` callbacks (`init`, `handle_call`, `handle_cast`, `handle_info`, `terminate`, `code_change`) and its relationship to supervisors.
- [Processes — Erlang/OTP Reference Manual (erlang.org)](https://www.erlang.org/doc/system/ref_man_processes.html) — links (bidirectional), exit signals, `trap_exit`, special reasons `normal`/`kill`/`killed`, monitors and the `{'DOWN', ...}` message.
- [Supervisor — Elixir HexDocs](https://elixir.hexdocs.pm/Supervisor.html) — Elixir's supervision strategies and defaults (`max_restarts` = 3, `max_seconds` = 5), restart values, "Supervision trees provide fault-tolerance."

Secondary / teaching (cross-checks, good for slide prose):

- [*Errors and Processes* — Learn You Some Erlang for Great Good!](https://learnyousomeerlang.com/errors-and-processes) — clear treatment of links vs monitors, `trap_exit`, `spawn_link`/`spawn_monitor`, and exit-signal propagation along chains.
- [*Who Supervises The Supervisors?* — Learn You Some Erlang](https://learnyousomeerlang.com/supervisors) — supervisor restart strategies and tree structure, with worked examples.
- [Erlang Garbage Collector — erts docs (erlang.org)](https://www.erlang.org/doc/apps/erts/garbagecollection.html) — per-process heap / per-process GC (supports the "no shared state to corrupt" claim).
- [DynamicSupervisor — Elixir HexDocs](https://hexdocs.pm/elixir/1.14/DynamicSupervisor.html) — modern replacement for the deprecated `:simple_one_for_one` strategy.

Note on the "nine nines" figure: the AXD301 nine-nines (99.9999999%) availability claim is
widely attributed to Joe Armstrong but is **not** stated as a verified measurement in the
thesis. It appears in his later talks/slides and is repeated second-hand across the web (e.g.
DockYard's *All For Reliability* and various conference write-ups). I could not locate a
primary, independently audited source for it, so it should be presented as an oft-quoted
industry claim rather than a rigorous benchmark.
