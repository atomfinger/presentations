# Why the BEAM, Even Without Hyperscale

## TL;DR

The big scale stories — millions of processes, WhatsApp's 2M connections, Discord's 5M
concurrent users — are great *hooks*, but they are the wrong reason for a normal team to pick
the BEAM. They describe a ceiling almost nobody hits. The real, everyday case is that the BEAM
gives an *ordinary* application a set of properties you would otherwise have to assemble (and
operate) out of separate pieces: **self-healing via supervision** (a crash isolates to one
request/process instead of taking the server down), **predictable tail latency with no GC
tuning** (per-process garbage collection, no global stop-the-world pause), **concurrency that
reads as straight-line code** (no async/await "function coloring", no reactive-stream
ceremony, no hand-tuned thread pools), and — the biggest small-team win — **operational
consolidation**: one BEAM app can be its own in-memory cache, pub/sub bus, background-job
runner, scheduler, rate limiter, and websocket server, which often removes Redis, a message
broker, and a separate worker tier from your architecture. On top of that you get **live
introspection in production** (remote-shell into a running node, read any process's state,
trace live function calls) and **high productivity for full-stack work** (in Gleam, the Lustre
framework builds rich real-time UIs — its server components are a type-safe analogue of Phoenix
LiveView — so a small team can ship a full-stack app in one language with little or no
hand-written JavaScript). The maintainability dividend is structural: immutability plus share-nothing processes means no
data races, no locks, no shared mutable state to corrupt.

The honest counterweights: a **smaller ecosystem** and **smaller hiring pool** than the JVM,
**lower raw single-threaded throughput** (a poor fit for heavy CPU-bound / numeric / ML work),
and a real **learning curve** (functional + immutable + OTP is unfamiliar to OO developers).
The pitch to a JVM audience is not "the BEAM is faster." It is: *the BEAM gives you resilience,
predictable latency, and operational simplicity by default — properties a Java team usually
buys with extra libraries, extra infrastructure, and extra tuning.*

---

## The everyday case for the BEAM

> **A note on Gleam, Elixir, and the BEAM ecosystem.** Every property in this document belongs
> to the **BEAM**, so it applies equally to Gleam, Elixir, and Erlang — the runtime, not the
> language, provides supervision, per-process GC, cheap processes, and distribution. The talk is
> about **Gleam**, so the examples below name **Gleam-native, type-safe libraries** where they
> exist: `gleam_otp` (typed actors + supervisors), [Lustre](https://github.com/lustre-labs/lustre)
> (frontend + real-time server components), [Wisp](https://github.com/gleam-wisp/wisp) + Mist
> (web framework + HTTP/websocket server), [glyn](https://github.com/mbuhot/glyn) (typed
> pub/sub & registry), and `pog` (Postgres). Gleam's ecosystem is younger and smaller than
> Elixir's — but because **Gleam compiles to Erlang and can call any Erlang/Elixir/Hex package
> via `@external`** ([externals guide](https://gleam.run/documentation/externals/);
> [`glixir`](https://hexdocs.pm/glixir/) gives *typed* wrappers over Elixir/Erlang GenServers,
> Supervisors and Registry), the entire mature BEAM ecosystem — Phoenix.PubSub, Oban, and the
> rest — is still directly available from Gleam. So the "fewer moving parts" argument holds for
> Gleam in **two** ways: Gleam-native libraries, *and* zero-cost reuse of the Erlang/Elixir
> ones. Where a Gleam-native option isn't mature yet, that's called out honestly below.

### 1. Reliability at any scale — supervision means even a small app self-heals

Fault tolerance on the BEAM does not depend on scale. The same mechanism that lets Discord
survive at 5M users protects a three-endpoint internal service. Because each process has its
own heap and shares nothing, **a crash is contained to the process that hit it** — the request
fails, that process dies, a supervisor restarts a clean one from a known-good state, and the
rest of the system never notices. (The deeper mechanics are in `02-fault-tolerance.md`.)

What this saves a normal team: you stop writing defensive `try/catch` woven through business
logic to guard against every conceivable failure. Recovery is a *structural* property pushed
out to supervisors, not a concern smeared across every function. Discord's engineers describe
exactly this mindset shift — one engineer initially "worried about data races and concurrency
issues that were impossible to happen," and productivity rose once the team trusted the
runtime's guarantees instead of coding around them
([elixir-lang.org Discord post](https://elixir-lang.org/blog/2020/10/08/real-time-communication-at-scale-with-elixir-at-discord/)).
The everyday lesson is independent of their scale: a bug in one request handler should degrade
one request, not topple the server. On a shared-heap runtime, an unhandled error in a thread
pool worker can corrupt shared state or exhaust the pool; on the BEAM, the blast radius is one
process.

*Be fair:* the JVM has good supervision-like patterns too (Akka/Pekko actors, resilience4j,
health checks, container restarts). The difference is that on the BEAM supervision is the
*default idiom* baked into OTP, not a library you choose and wire up.

### 2. Predictable latency — per-process GC, no GC tuning rabbit hole

The BEAM garbage-collects **per process**. Each process owns a private heap, so GC runs on one
process's small heap at a time and **there is no global, heap-wide stop-the-world pause** that
freezes the whole runtime. When a short-lived process (e.g. one request) finishes, its heap is
reclaimed wholesale. The practical effect is **consistent tail latency** — the p99 of a small
service does not get periodically wrecked by a multi-hundred-millisecond full GC, and you get
this **by default, with no flags to choose and no heap sizes to tune.**

What this saves a normal team: the JVM GC-tuning rabbit hole. Even a modest Java service can
end up reasoning about generation sizes, collector choice, and pause budgets.

*Be scrupulously fair here* — this is where a Java audience will (rightly) push back: modern
JVM collectors are excellent. **ZGC** delivers sub-millisecond pauses largely independent of
heap size (commonly cited at ~0.1–0.5 ms, with rare ~1 ms spikes), and **Shenandoah**
typically lands in the low-single-digit-millisecond range; both do most work concurrently with
application threads
([gceasy: ZGC vs Shenandoah](https://blog.gceasy.io/zgc-vs-shenandoah-java-gc/),
[Gunnar Morling: Lower Java tail latencies with ZGC](https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/)).
So the honest framing is **not** "the JVM pauses and the BEAM doesn't." It is: on the JVM you
have to *know these collectors exist, select one, and often size the heap and accept a
CPU/memory overhead* (ZGC trades roughly 15–30% more memory and ~5–10% more CPU for those
pauses). On the BEAM, per-process collection with no global pause is simply how the runtime
works, with nothing to choose. The win is "good default" vs. "good if you tune it."

### 3. Concurrency that's simple to write — no function coloring, no reactive ceremony

In languages with `async`/`await`, functions split into two incompatible kinds. Bob Nystrom's
classic essay **"What Color is Your Function?"** (2015) frames this as function *colors*: "red"
(async) functions can only be called from other red functions and are "more painful to call,"
so asynchrony is contagious and leaks through your entire call graph
([journal.stuffwithstuff.com](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/)).
Nystrom singles out approaches that **eliminate** the distinction — threads/goroutines/fibers
in Go, Lua, and Ruby — because concurrency becomes "a facet of how *you* choose to model your
program, and not a color seared into each function." (His essay does not discuss Erlang/BEAM,
but the BEAM belongs squarely in that camp: a process is just a function running on a
scheduler, and blocking it blocks only that process.)

On the BEAM there is no function coloring. You write straight-line, synchronous-looking code; a
call that "blocks" (sending a message and waiting for a reply, doing I/O) only parks *that*
process while the scheduler runs others. There is **no async/await to thread through your code,
no `CompletableFuture` chains or reactive-stream operators to learn, and no hand-tuned thread
pools** — the runtime runs one scheduler per core and preempts processes fairly via reduction
counting (see `03-concurrency.md`). Each request runs in its own isolated process.

What this saves a normal team: you do not pay the "color tax." You do not maintain two flavors
of every function, fight back-pressure operators in a reactive library, or size and starve
thread pools. The simplest code you can write *is already* concurrent and isolated.

*Be fair:* **Java 21 virtual threads (Project Loom, JEP 444)** close much of this gap — they
let you write blocking-style code that scales, removing a lot of the async/reactive ceremony.
That is real convergence toward the BEAM model. Differences remain: a shared heap and shared
GC, cooperative scheduling without time-slicing, pinning edge cases, and no built-in
per-process isolation, mailboxes, or supervision.

### 4. Operational consolidation — fewer moving parts (the biggest small-team win)

This is the argument that should land hardest with a team that does *not* expect hyperscale,
because it is about **infrastructure you don't have to run.** A typical web stack bolts on
external services for things the language can't do in-process: Redis for caching and pub/sub, a
message broker for events, a separate worker tier for background jobs, a scheduler for cron.
Each is another thing to deploy, monitor, secure, and recover when it breaks.

The BEAM collapses many of these into the application itself:

- **In-memory cache → ETS** (Erlang Term Storage), a concurrent key/value store built into the
  runtime. It's a *BEAM primitive*, not an Elixir feature, so a Gleam app reaches it directly
  (with typed wrappers available on Hex) — no Redis round-trip for ephemeral data.
- **Pub/sub & message broker → [`glyn`](https://github.com/mbuhot/glyn)** (type-safe pub/sub +
  registry for Gleam actors, built on Erlang's `syn`, with distributed clustering) or
  **`simple_pubsub`** (built on Erlang process groups, `pg`) — broadcast across a cluster with
  no external broker. *(If you want Elixir's battle-tested Phoenix.PubSub instead, it's callable
  from Gleam via FFI.)*
- **Presence (who's online)** → built on pub/sub + CRDTs. There's no mature *Gleam-native*
  presence library yet, so you either build it on `glyn`/`pg` or call **Phoenix Presence** via
  FFI. (Honest gap — flag it as such.)
- **Background jobs & scheduler/cron** → for in-process scheduling, a supervised `gleam_otp`
  actor. For a *durable*, Postgres-backed queue there's no mature Gleam-native **Oban**
  equivalent yet, so you call Oban (Elixir) via FFI/`glixir`, or back a simple queue with `pog`
  + Postgres — either way, no Redis-backed queue and no separate worker fleet.
- **Websocket server → Mist** (the Gleam HTTP server, with websocket support) under
  [Wisp](https://github.com/gleam-wisp/wisp), in the same app.
- **Rate limiter / coordination → a `gleam_otp` actor + ETS**, plain *typed* in-process state.

The framing comes straight from the ecosystem's leaders — stated in Elixir terms, but it
describes a **BEAM** property that a Gleam app gets the same way (Gleam-native libraries, or
direct reuse of these very Elixir/Erlang ones). José Valim's Dashbit post is titled,
plainly, **"You may not need Redis with Elixir"** — its thesis: "if you have ephemeral data in
Elixir, the odds are that you may not need Redis," because Erlang's native clustering and
multi-core concurrency cover distributed pub/sub, presence, caching, and async processing
in-runtime; a basic distributed pub/sub is "200LOC or less"
([dashbit.co](https://dashbit.co/blog/you-may-not-need-redis-with-elixir)). Fly.io's
**"Elixir and Phoenix can do it all!"** post maps the replacements one-for-one — message
brokers → Phoenix.PubSub, caching layers → ETS, background workers → Oban/GenStage/Broadway,
websocket servers → Channels, cron → Oban — and quotes Valim's deeper point about
**"removing the problem altogether instead of solving the problem"**
([fly.io](https://fly.io/phoenix-files/elixir-and-phoenix-can-do-it-all/)). Saša Jurić's
*Elixir in Action* makes the same case at book length, presenting the BEAM as a self-contained
platform for "scalability, concurrency, fault tolerance, and high availability"
([manning.com](https://www.manning.com/books/elixir-in-action)).

What this saves a normal team: **fewer services to run, fewer network hops, fewer failure
modes, and a smaller bill.** Every external dependency you delete is one fewer thing to page
you at 3 a.m. For a small team without a platform/SRE group, removing Redis + a broker + a
worker tier is often a larger reliability and velocity win than any raw-performance number.
*Caveat:* this applies to *ephemeral* state; you still want a real database for durable data,
and PubSub messages are at-most-once, not a durable broker replacement.

### 5. Live introspection & debugging in production

On most stacks, debugging a misbehaving production service means adding logging, redeploying,
and hoping you captured the right thing. On the BEAM you can **attach to the running system and
look.** You can open a remote shell into a live node (`iex --remsh`), then:

- read any process's internal state with **`:sys.get_state/1`** — without adding a handler or
  redeploying;
- explore the whole node visually with **`:observer`** (processes, memory, message-queue
  lengths, ETS tables, schedulers);
- **trace live function calls** safely in production with **`recon`**, which pattern-matches on
  which calls to capture, caps output, and shuts itself off on disconnect so a stray trace
  can't take the node down
  ([fmcgeough.github.io: Debugging Elixir in Production](https://fmcgeough.github.io/blog/2024/debug-in-production/)).

Discord describes this as a day-to-day capability, not a stunt: **"We can look at any VM
process in the cluster and see its message queue. We can use the remote shell to connect to any
node and debug a live system."**
([elixir-lang.org](https://elixir-lang.org/blog/2020/10/08/real-time-communication-at-scale-with-elixir-at-discord/))

The canonical live demonstration of all of this is Saša Jurić's talk **"The Soul of Erlang and
Elixir" (GOTO 2019)**, which sets out to show "what makes Erlang and Elixir suitable" for
server-side systems by "looking past the syntax and the ecosystem" to the concurrency model,
"combining a bit of high-level theory and a couple of demos"
([gotochgo.com abstract](https://gotochgo.com/2019/sessions/712/the-soul-of-erlang-and-elixir),
[YouTube](https://www.youtube.com/watch?v=JvBT4XBdoUE)). It is the best single artifact to point
a skeptical audience at.

What this saves a normal team: introspection superpowers that normally require a big
observability investment, available to a team with no SRE org. You can diagnose a live incident
by reading the actual state of the running system instead of guessing from logs.

### 6. Productivity — full-stack Gleam and real-time UIs with little or no JavaScript

The pattern: keep UI state on the **server** and push only the changed parts of the DOM to the
browser over a WebSocket, so you build interactive features (validation, autocomplete, live
updates, even small games) without a separate front-end SPA. **Phoenix LiveView** popularized
and proved this pattern on the BEAM — Chris McCord's 2018 announcement put it bluntly,
**"you don't need to write a single line of JavaScript,"** and noted LiveView "often sends
*less* data than an equivalent client-rendered application"
([dockyard.com](https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript));
it reached a stable **1.0 release on 2024-12-03** and now ships by default in new Phoenix apps
([phoenixframework.org](https://www.phoenixframework.org/blog/phoenix-liveview-1.0-released)).
That's the proof the *pattern* works; the question for this talk is what **Gleam** offers.

**Gleam's answer is [Lustre](https://github.com/lustre-labs/lustre).** It's an Elm/MVU-style
framework that compiles to JavaScript for ordinary single-page apps — *and* it offers **server
components**: the Model-View-Update loop runs on the server (the Erlang runtime), all state
lives server-side, and a lightweight (~10 kB) client receives DOM patches over a transport
(WebSocket, SSE, or polling). In other words, a **type-safe Gleam analogue of LiveView** —
Lustre even ships a ["For LiveView developers" cheatsheet](https://hexdocs.pm/lustre/cheatsheets/liveview.html).
[**Sprocket**](https://hexdocs.pm/sprocket/) is a second Gleam framework, explicitly inspired by
Phoenix LiveView and React.

The twist that matters for *this* talk: with Lustre you write the **frontend in Gleam too** (it
compiles to JS), so a **full-stack application in pure Gleam is real** — Lustre for the UI,
[Wisp](https://github.com/gleam-wisp/wisp) + Mist for the HTTP/WebSocket backend, `pog` for
Postgres — with **one type system spanning client and server** and types shared across the wire.
(This is precisely the "full-stack app written in pure Gleam" from the talk outline, and a
stronger story than LiveView's, where the client is still HEEx/JS rather than the same language.)

What this saves a normal team: you can drop the entire second codebase — the JSON API layer,
the client-side state management, the separate JS toolchain — for the common case where you need
rich interactivity but not an offline-first SPA. A few people can ship a live, real-time product
surface that would otherwise need a dedicated front-end team. *Honest caveats:* Lustre and
Sprocket are **younger and far less battle-tested than LiveView**; Lustre server components have
no built-in PubSub (LiveView does), so cluster-wide live updates need a separate pub/sub such as
`glyn`; and, like LiveView, server components assume a live connection and server round-trips, so
they're a poor fit for offline-first or zero-latency-input UIs.

### 7. Maintainability — immutability + isolation means fewer concurrency bugs

The maintainability win is the flip side of the concurrency model. Data is **immutable** and
processes **share nothing**, so an entire class of bugs simply cannot occur: **no shared mutable
state, no data races, no lock-ordering deadlocks, no torn reads.** As one summary of the Discord
architecture puts it: "There are no mutexes. There are no race conditions. There is no shared
state to corrupt."

What this saves a normal team: code you can reason about locally. To understand a process you
read its state transitions in isolation; you don't have to hold the whole program's locking
discipline in your head, and refactors don't risk introducing a subtle race in code you didn't
touch. This is the property a Java developer pays for with `synchronized`, `volatile`,
concurrent collections, and careful lock ordering — on the BEAM it is the default, because
there is nothing shared to protect.

---

## When NOT to pick the BEAM

Credibility depends on being honest about the trade-offs. There are good reasons a JVM team
might *not* switch:

- **Smaller ecosystem & library selection.** The JVM has a vast, mature library and tooling
  ecosystem (Maven Central, decades of enterprise integrations). On the BEAM you will
  occasionally find no mature library for a niche need and have to write what you'd otherwise
  import, or call out to another runtime.
- **Smaller hiring pool / less familiarity.** Far more developers know Java than Elixir/Erlang/
  Gleam. Hiring, onboarding, and "the next maintainer" are real organizational costs. (The flip
  side — Discord and others run large systems with very small teams — is a productivity argument,
  not a hiring-market one.)
- **Lower raw single-threaded throughput; bad fit for CPU-bound work.** The BEAM optimizes for
  massive concurrency, soft-real-time latency, and fault tolerance — *not* for crunching numbers
  on one core. For heavy CPU-bound, numeric, or ML workloads, the JVM (or Rust/C/Go) will be
  substantially faster per core. On the BEAM you push that work out to NIFs/ports or another
  language (e.g. Rust via Rustler), which adds complexity. If your bottleneck is arithmetic, not
  I/O and concurrency, the BEAM is the wrong default.
- **Learning curve.** Functional programming, immutability, pattern matching, and especially the
  OTP mental model (processes, supervision trees, `gen_server`) are genuinely unfamiliar to
  developers coming from imperative/OO Java. Teams should budget real ramp-up time; "let it
  crash" and "model your domain as processes" take a while to feel natural.

A fair one-line summary: **pick the BEAM for I/O-bound, concurrent, long-lived, reliability- and
latency-sensitive systems; do not pick it for CPU-bound number crunching, and weigh the
ecosystem/hiring cost against the operational simplicity it buys you.**

---

## Why it matters for the talk / what JVM folks can learn

The trap with a BEAM talk is leaning on the scale stories. A JVM dev building a modest internal
service hears "2 million connections" and correctly concludes "irrelevant to me." This section is
the persuasive core *because* it answers the real question: **why reach for the BEAM when you do
NOT expect massive scale and Java is the default?**

How to land it with a Java audience:

1. **Lead with operational consolidation, not scale.** The strongest, most concrete pitch is
   "delete Redis, the broker, and the worker tier." Every Java team has felt the pain of
   operating those. Frame it as *fewer moving parts*, then back it with Valim's "you may not
   need Redis" and Fly.io's "Elixir and Phoenix can do it all." For a *Gleam* talk, show the
   consolidation with Gleam-native libraries (`glyn` for pub/sub, ETS for cache, a `gleam_otp`
   actor for coordination) and make the honest point that anything not yet mature in Gleam can
   be borrowed from Elixir/Erlang via FFI — Gleam inherits the whole BEAM ecosystem.

2. **Be the honest one in the room about GC.** Don't claim the JVM pauses and the BEAM doesn't —
   a knowledgeable audience knows about ZGC and will tune you out. Say it straight: modern JVM
   collectors are excellent *if you choose and tune them*; the BEAM gives you predictable
   latency *by default, with nothing to tune.* "Good default vs. good-if-you-tune-it" is the
   honest, defensible line.

3. **Acknowledge Loom up front.** Java 21 virtual threads close much of the concurrency-ergonomics
   gap. Saying so first earns trust; then you can point to what virtual threads *don't* give:
   per-process isolation, supervision, share-nothing heaps, mailboxes — i.e. the reliability
   model, not just the concurrency model.

4. **Make the "function color" point visually.** Nystrom's red/blue framing is instantly
   relatable to anyone who has fought `CompletableFuture` chains or reactive streams. The BEAM
   (like Loom) is the "no colors" world: straight-line code is concurrent.

5. **Show, don't tell, the introspection.** Jurić's "Soul of Erlang and Elixir" demo (remote
   shell into a live node, watch a supervisor heal a crash, inspect process state) is the single
   most persuasive thing you can put on screen — it makes "self-healing" and "debug the live
   system" tangible rather than slogans.

6. **Close with the pure-Gleam full-stack demo.** A small app with Lustre on the front,
   Wisp/Mist on the back, `gleam_otp` actors for state, and *one* type system spanning client
   and server is the part of the talk that's distinctly **Gleam**, not just BEAM — concrete proof
   of the productivity and maintainability claims, and a natural payoff for the audience.

Quotable talking points:

- *"The scale stories are the hook. The reason a normal team should care is that the BEAM
  deletes infrastructure."*
- *"On the JVM you get low pauses if you pick ZGC and tune the heap. On the BEAM you get them by
  default, because GC is per-process and there's no global stop-the-world."*
- *"There are no mutexes, no race conditions, no shared state to corrupt — that's a
  maintainability property, not just a performance one."*
- *"Supervision means a bug fails one request, not the whole server — and you didn't write any
  defensive code to get that."*
- *"Loom gives Java cheap concurrency. It does not give Java supervision, isolation, and
  mailboxes. That's the part of the BEAM worth stealing."*
- *"Gleam is young, but it runs on the BEAM and compiles to Erlang — so it inherits 30 years of
  runtime, and can call any Elixir or Erlang library while the Gleam-native one matures."*
- *"In Gleam you can write the backend, the frontend, and the actors in one language, with one
  type system — and it all runs on the same VM that survives telecom-grade failures."*

The meta-lesson for JVM folks even if they never write a line of Elixir: **resilience,
predictable latency, and operational simplicity can be runtime defaults rather than things you
assemble out of libraries and infrastructure.** That idea is portable — it's why Loom, actor
libraries, and "let it crash" patterns keep showing up on the JVM.

---

## Sources

Primary / authoritative (retrieved and verified):

- **José Valim (Dashbit), "You may not need Redis with Elixir"** —
  <https://dashbit.co/blog/you-may-not-need-redis-with-elixir> — Core source for operational
  consolidation. Thesis quote verified: "if you have ephemeral data in Elixir, the odds are that
  you may not need Redis." Covers distributed pub/sub, presence, caching, async processing as
  in-runtime replacements. Published 2020-11-11, by the creator of Elixir.

- **Fly.io, "Elixir and Phoenix can do it all!"** —
  <https://fly.io/phoenix-files/elixir-and-phoenix-can-do-it-all/> — Maps external services to
  BEAM/Phoenix features one-for-one (broker→PubSub, cache→ETS, jobs→Oban, websockets→Channels,
  cron→Oban). Quotes Valim's "removing the problem altogether instead of solving the problem."
  Dated 2023-10-26. (Note: the precise verbatim wording of the feature-mapping slide was
  summarized by the fetch tool, not copied character-for-character — verify exact phrasing
  against the page before quoting on a slide.)

- **elixir-lang.org, "Real time communication at scale with Elixir at Discord"** —
  <https://elixir-lang.org/blog/2020/10/08/real-time-communication-at-scale-with-elixir-at-discord/>
  — Source for live-introspection and small-team productivity. Verified quote: "We can look at
  any VM process in the cluster and see its message queue. We can use the remote shell to connect
  to any node and debug a live system." Reframe for the everyday lesson, not the 5M-user number.

- **Bob Nystrom, "What Color is Your Function?" (2015)** —
  <https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/> — The function-
  coloring essay. Verified: red functions "can only be called from other red functions," are
  "more painful to call"; Go/Lua/Ruby threads "eliminated the distinction." Does **not** mention
  Erlang/BEAM (noted in text).

- **Phoenix LiveView announcement, Chris McCord / DockYard (2018-12-12)** —
  <https://dockyard.com/blog/2018/12/12/phoenix-liveview-interactive-real-time-apps-no-need-to-write-javascript>
  — Verified quotes: "you don't need to write a single line of JavaScript"; "LiveView often sends
  *less* data than an equivalent client-rendered application."

- **Phoenix LiveView 1.0 release** —
  <https://www.phoenixframework.org/blog/phoenix-liveview-1.0-released> — 1.0.0 released
  2024-12-03 (per Phoenix blog / search). Repo + tagline:
  <https://github.com/phoenixframework/phoenix_live_view> ("Rich, real-time user experiences with
  server-rendered HTML").

- **Saša Jurić, "The Soul of Erlang and Elixir" (GOTO 2019)** —
  <https://www.youtube.com/watch?v=JvBT4XBdoUE> (video),
  <https://gotochgo.com/2019/sessions/712/the-soul-of-erlang-and-elixir> (verified abstract). The
  canonical live demo of isolation, supervision/self-healing, and live introspection.

- **Saša Jurić, *Elixir in Action* (Manning)** —
  <https://www.manning.com/books/elixir-in-action> — Book-length "BEAM as a platform" framing
  (scalability, concurrency, fault tolerance, high availability). Used for the platform framing;
  no specific page quote was pulled.

JVM-side fairness checks (retrieved/searched):

- **gceasy.io, "ZGC vs. Shenandoah"** — <https://blog.gceasy.io/zgc-vs-shenandoah-java-gc/> —
  Used for the honest GC caveat: ZGC ~0.1–0.5 ms pauses, Shenandoah low-single-digit ms; both
  mostly concurrent. (Figures via search summary — treat the exact numbers as approximate; the
  qualitative claim "modern JVM collectors give low pauses but must be chosen/tuned" is the
  load-bearing one.)

- **Gunnar Morling, "Lower Java tail latencies with ZGC"** —
  <https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/> — Reputable practitioner
  source corroborating ZGC's low-tail-latency benefit (title verified via search; page not
  individually fetched).

- **Production debugging: "Debugging Elixir in Production"** —
  <https://fmcgeough.github.io/blog/2024/debug-in-production/> — Source for `:sys.get_state`,
  `:observer`, `recon` safe live tracing.

Gleam ecosystem (the libraries named above — verified via current Hex/GitHub pages, June 2026):

- **`gleam_otp`** — <https://github.com/gleam-lang/otp> / <https://hexdocs.pm/gleam_otp/> —
  Gleam's typed actors and supervisors; "fully typed interface… each message is explicitly typed
  and traceable," with Erlang-OTP-equivalent fault tolerance.
- **Lustre** — <https://github.com/lustre-labs/lustre> and the
  ["For LiveView developers" cheatsheet](https://hexdocs.pm/lustre/cheatsheets/liveview.html) —
  Gleam frontend framework (compiles to JS) **and** real-time **server components** (MVU on the
  server, ~10 kB client, DOM patches over WebSocket/SSE/polling). The LiveView analogue for Gleam.
- **Sprocket** — <https://hexdocs.pm/sprocket/> — Gleam framework for real-time server UI
  components, "heavily inspired by Phoenix LiveView and React."
- **Wisp** — <https://github.com/gleam-wisp/wisp> / <https://gleam-wisp.github.io/wisp/> —
  Practical Gleam web framework (handlers + middleware, type-safe routing) running on the **Mist**
  HTTP/WebSocket server. With `pog` (Postgres) this is the pure-Gleam full-stack backend.
- **`glyn`** — <https://github.com/mbuhot/glyn> / <https://hexdocs.pm/glyn/> — type-safe pub/sub
  + registry for Gleam actors, built on Erlang's `syn`, with distributed clustering. The
  Gleam-native answer to "Phoenix.PubSub." (`simple_pubsub` is a lighter option built on `pg`.)
- **`glixir`** — <https://hexdocs.pm/glixir/> — *typed* OTP interop: use Elixir/Erlang
  GenServers, Supervisors, Agents and Registry from Gleam — the bridge that makes "borrow the
  Elixir library" safe.
- **Gleam externals/FFI** — <https://gleam.run/documentation/externals/> — `@external` to call
  Erlang/Elixir/JS; any Hex package can be added in `gleam.toml`. The basis for the claim that
  Gleam inherits the whole BEAM ecosystem. (See also Erlang Solutions'
  ["Gleam's Interoperability with Erlang and Elixir"](https://www.erlang-solutions.com/webinars/gleams-interoperability-with-erlang-and-elixir/).)

Cross-referenced in-repo: `02-fault-tolerance.md` (supervision / "let it crash"),
`03-concurrency.md` (per-process heaps, schedulers, reduction counting, Loom/virtual threads
comparison). Java 21 virtual threads = **JEP 444** (referenced from `03-concurrency.md`, not
re-fetched here).
