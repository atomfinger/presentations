# Distribution on the BEAM

## TL;DR

The BEAM is **"distributed by default"** in a very specific, honest sense: the runtime
ships with the *primitives* to turn a set of separate VM instances ("nodes") into a
cluster, and — crucially — **the same actor/message-passing API works whether the target
process is on the local machine or another node across the network**. `Pid ! Msg` to a
remote pid, `spawn/4` to start a process on another node, and the `rpc` module all behave
the same as locally; pids carry their origin node, so location is transparent. This is the
real headline: on the JVM, distribution is a *library/framework* concern (Akka/Pekko
Cluster, Netty, gRPC, Hazelcast); on the BEAM it is a *runtime* concern.

Nodes find each other via **`epmd`** (the Erlang Port Mapper Daemon, a per-host name→port
directory) and "authenticate" with a shared **magic cookie**. By default connections are
**transitive**: when A connects to B and B knows C, A also connects to C, producing a
**fully connected mesh**. OTP layers building blocks on top — `global` (cluster-wide name
registry + locks), `pg` (process groups / pub-sub), `mnesia` (distributed database),
`rpc`. These primitives are **language-agnostic** — a Gleam program uses them like any BEAM
language. Higher-level wrappers differ per language: Elixir adds `libcluster` (auto cluster
formation), Phoenix PubSub/Presence, and distributed registries (Horde/Syn); Gleam adds typed
ones such as `glyn` (pub/sub + registry on `syn`) and can call the Elixir libraries directly via
FFI. At larger scale, **partisan** replaces disterl's one-size-fits-all full mesh with pluggable
topologies.

The sharp edges, stated honestly: "distributed by default" gives you **primitives and
transparency, not automatic correctness**. The full mesh practically caps clusters at
**~60–200 nodes** (often "a couple of dozen" in practice) before O(n²) connection chatter
dominates. `global` can become **internally inconsistent under overlapping network
partitions**; `mnesia` has well-known **split-brain** recovery pain and explicitly leaves
"which side wins" to you. And the default distribution protocol is **a single trust
domain**: the cookie is not real authentication, traffic is unencrypted unless you turn on
TLS, and any node admitted to the cluster gets **complete access to all other nodes**.

## Key facts & mechanics

### What a node is

- A **node** is "an executing Erlang runtime system that has been given a name." You name
  it with `-name` (long names, e.g. `app@host.example.com`) or `-sname` (short names, e.g.
  `app@host`). Names take the form `name@host`. (erlang.org, *Distributed Erlang*.)
- A node with a **long** name cannot talk to a node with a **short** name — they must
  match. (erlang.org.)
- Multiple nodes can run on one machine; "node" means a named BEAM instance, not a host.

### `epmd` — the Erlang Port Mapper Daemon

- `epmd` is "automatically started at every host where an Erlang node is started." It is a
  small per-host daemon "responsible for mapping the symbolic node names to machine
  addresses" — i.e. a name→TCP-port directory so a connecting node can find the listening
  port of `app@host`. (erlang.org, *Distributed Erlang*.)
- Security note (see caveats): `epmd` "will respond to unauthenticated requests, and can by
  this leak information about what Erlang nodes exist and what ports they are listening on."
  (erlang.org, *Secure Coding Guidelines*.)

### The magic cookie

- Each node has a **magic cookie**, an Erlang atom. "During the connection setup, after
  node names have been exchanged, the magic cookies the nodes present to each other are
  compared. If they do not match, the connection is rejected." (erlang.org, *Distributed
  Erlang*.)
- At startup a node reads `~/.erlang.cookie` (created with permissions octal `400`,
  read-only by owner, containing a random string) and uses its contents as the cookie. You
  can also set it programmatically with `erlang:set_cookie/1,2`. (erlang.org.)
- **The cookie is not authentication.** It exists "to prevent the unintentional mixing of
  Erlang clusters on the same network." Learn You Some Erlang puts it bluntly: treating the
  cookie as a security feature "has to be seen as a joke" — it is "closer to the idea of
  user names than passwords." (erlang.org, *Secure Coding*; LYSE, *Distribunomicon*.)

### Connecting nodes → the full mesh

- Connections are established lazily (on first message/attempt) and are by default
  **transitive / automatic**: "When node A connects to node B, and B connects to C, then A
  automatically attempts connection to C," creating a fully connected mesh. You disable this
  with `-connect_all false`. (erlang.org, *Distributed Erlang*.)
- LYSE's gloss: "everyone connects to everyone"; a new node joining a connected group
  automatically connects to *all* existing nodes, so "in the event of the death of any
  survivor, nobody's left isolated." (*Distribunomicon*.)
- **Hidden nodes** (`-hidden`) connect point-to-point *without* joining the transitive
  mesh and don't show up in `nodes/0` (they appear in `nodes(hidden)`). Useful for tools,
  observers, and bridges that should not pull the whole cluster together. (erlang.org; LYSE.)
- Useful BIFs: `node()` (this node's name), `nodes()` (connected visible nodes),
  `net_kernel:connect_node/1` (force a connection; returns `false` if cookies mismatch),
  `net_adm:ping/1`. `net_kernel` controls the distribution lifecycle (start distribution,
  set net tick time, etc.). (erlang.org; LYSE.)

### Location transparency — the core "distributed by default" point

The same primitives work locally and remotely. This is the part JVM developers should pay
attention to:

- **Send to a remote pid:** `Pid ! Msg` works regardless of which node the pid lives on.
  Pids encode their origin node in their binary representation, so the runtime routes the
  message transparently. You can also send to a *registered name on a remote node* with
  `{RegName, Node} ! Msg`. (LYSE; erlang.org.)
- **Spawn on a remote node:** `spawn(Node, Fun)` and `spawn/4`
  (`spawn(Node, Module, Function, Args)`) start a process **on another machine** — same
  call shape as local `spawn`. (erlang.org; LYSE.)
- **`rpc`:** `rpc:call(Node, Module, Function, Args)` runs a function on a remote node and
  returns the result; variants include `rpc:async_call/4`, `rpc:multicall/4` (call on many
  nodes), and `rpc:cast/4` (fire-and-forget). (erlang.org; LYSE.)
- LYSE summarizes the property as "pretty complete network transparency": "All data
  structures, including pids, will work the same remotely and locally." Links and monitors
  also work across nodes, so OTP supervision and failure detection extend across the
  cluster.

The mental model JVM folks should take away: **on the BEAM, "another machine" is just
another address for the same message-passing model.** There is no separate networking API
to learn for the basic case — the actor model *is* the distribution model.

### Building blocks in OTP

- **`global`** — cluster-wide service providing (1) **globally registered names**
  (register a pid under a name visible on every node), (2) **global locks**, and (3)
  "maintenance of the fully connected network." Names are replicated across nodes with
  conflict resolution. (erlang.org, *global*.)
- **`pg`** — distributed named **process groups** ("Process Groups"). A process can join
  any number of groups, and you can send to one, some, or all members — the basis for
  pub/sub and worker-pool patterns across a cluster. `pg` replaced the older `pg2` (which
  was deprecated in OTP 23 and removed in OTP 24); `pg` is more scalable, supports
  independent **scopes**, and does **not** depend on `global` or take a cluster-wide lock.
  (erlang.org, *pg*; OTP 23 release notes.)
- **`mnesia`** — a distributed, transactional, in-memory/disk database built into OTP.
  Tables can be replicated across nodes; supports transactions and "dirty" fast paths. Good
  for soft-state and config that must be cluster-visible; *not* a CP datastore under
  partitions (see caveats). (erlang.org.)
- **`rpc`** — as above; the simplest "do X over there" primitive.

The same BEAM primitives are reachable from **any** BEAM language — a Gleam app calls
`global`/`pg`/`rpc`/`mnesia` directly — and each language wraps them in higher-level libraries.

In **Elixir-land**:

- **`libcluster`** — automatic cluster formation/healing. Pluggable strategies (Kubernetes,
  DNS polling, EC2 tags, UDP gossip, static epmd lists) discover peers and call
  `Node.connect/1` for you, so you don't hand-wire nodes; it runs the topology under
  supervision and reacts to `nodeup`/`nodedown`. (bitwalker/libcluster, GitHub.)
- **Phoenix PubSub** — cluster-wide pub/sub used by Phoenix Channels; historically backed by
  `pg2`/`pg`, it broadcasts messages to subscribers across all connected nodes.
- **Phoenix Presence** — distributed presence tracking built on a CRDT, so per-node
  presence state converges without a single coordinator (partition-tolerant by design).
- **Distributed registries / process distribution** — e.g. **Horde** (CRDT-based
  distributed `Registry` + `DynamicSupervisor`) and **Syn**, for "where does process X
  live across the cluster" and cluster-wide singletons.

In **Gleam-land** (younger, type-safe):

- **`glyn`** — type-safe pub/sub + registry for Gleam actors, built on the **same `syn`
  library** Elixir uses, with distributed clustering across nodes. (mbuhot/glyn, GitHub/Hex.)
- **`simple_pubsub`** — a lighter pub/sub built directly on Erlang process groups (`pg`);
  **`chip`** — a registry for grouping and looking up processes.
- For wrappers Gleam doesn't have yet (e.g. `libcluster`-style auto-formation, Horde), call the
  Elixir/Erlang library via FFI — **`glixir`** provides type-safe wrappers over OTP interop.

### JInterface — Java as a BEAM node

**JInterface** is an official Erlang/OTP application — shipped with every OTP installation — that
implements the Erlang external term format and the distribution protocol in Java. It lets a JVM
process join a BEAM cluster as a named node and exchange Erlang messages with BEAM processes
directly, no REST layer, no separate broker.

- A Java program creates an **`OtpNode`** (a named BEAM node), opens **`OtpMbox`** mailboxes
  (analogous to registered pids), and sends/receives Erlang terms as typed Java objects —
  `OtpErlangAtom`, `OtpErlangTuple`, `OtpErlangBinary`, etc. The Java node authenticates with
  the same magic cookie and appears in `nodes()` like any other node. A Gleam or Erlang process
  can address it with `{mailbox_name, java_node_name} ! Msg`. (erlang.org, *JInterface User's Guide*.)
- **The talk's use case:** **gradual migration**. A legacy Java service can keep running and
  exchange Erlang messages with a new Gleam service over the standard distribution protocol —
  no big-bang rewrite required. JInterface is proof that "join the BEAM cluster" is not an
  Erlang-only privilege.
- **Honest caveats:** the API is deliberately **low-level**. You construct terms by hand
  (`new OtpErlangTuple(new OtpErlangObject[]{atom, binary})`), there is no Java supervision
  tree, no OTP behaviours, and no typed message contracts on the Java side. It is a
  **bridge** at the distribution-protocol level, not a first-class OTP participant. For the
  basic "send a request, receive a reply" seam between Java and BEAM it works well; for
  anything complex on the Java side, the ergonomics fight you. Most teams use it for a narrow
  integration seam, not as a general Java-BEAM architecture.
- Source: https://www.erlang.org/doc/apps/jinterface/jinterface_users_guide.html *(official
  OTP docs — fetched directly)*

### partisan — beyond the default full mesh

- **partisan** is an alternative distribution layer for the BEAM that **bypasses disterl's
  full mesh**. It lets the application choose the overlay topology *at runtime* rather than
  baking topology assumptions into code: full mesh, **HyParView** peer-to-peer (for
  high-scale, high-churn clusters), client–server/star, and static membership. (Meiklejohn &
  Miller, *Partisan: Enabling Cloud-Scale Erlang Applications*; lasp-lang/partisan README.)
- It also splits traffic over **multiple TCP connections** between node pairs (disterl uses
  a single connection, conflating control-plane and application messages — a head-of-line
  blocking hazard). Reported gains: "up to 18x better under normal conditions," "up to 30x
  better" under congestion/high concurrency, and the ability to "scale to clusters of
  thousands of nodes." (Partisan paper / README.)

## Numbers & benchmarks

- **Full-mesh scaling limit (the number to cite):** the partisan README states that, due to
  heartbeating and internal data-structure costs, "Erlang systems present a limit to the
  number of connected nodes that depending on the application goes between **60 and 200
  nodes**." (lasp-lang/partisan README / hexdocs.)
- **Practical rule of thumb:** "a couple of dozen nodes, but probably not hundreds," because
  the cluster is fully connected and "communication overhead… increases **quadratically**
  with the number of nodes" — i.e. **O(n²)** connections, each an expensive TCP link with
  continual keep-alive (tick) traffic. (LYSE / partisan framing.)
- **Research evidence (SD Erlang):** *Scaling Reliably: Improving the Scalability of the
  Erlang Distributed Actor Platform* (arXiv 1704.07234) finds that "maintaining global
  recovery data dramatically limits scalability," and that SD Erlang's network partitioning
  "improves performance of the Orbit and ACO benchmarks **above 80 hosts**." So the
  bottleneck is the combination of full connectivity *and* global coordination, not raw
  process count. (Note: I retrieved the abstract only; the precise per-benchmark
  degradation points, e.g. 40 vs 140 nodes, are quoted in secondary summaries but I could
  not confirm them in the primary text — see unverified claims.)
- **Tick time:** the default net tick is ~60s split into ~4 ticks (~15s heartbeat interval);
  a node is considered down after ~4 missed ticks. Large messages can delay heartbeats on
  the shared TCP connection, which is part of why the mesh gets fragile at scale. (LYSE;
  `net_kernel:set_net_ticktime/1`.)

Caveat on the headline number: **"60–200 nodes" is a guideline, not a hard ceiling.** It is
workload-dependent (chatty global ops fail earlier; quiet clusters last longer), and tools
like partisan or SD Erlang push it much higher. Cite it as "practically dozens, up to a
couple hundred with care," not as a fixed law.

## Nuance & caveats

This section is the honest counterweight to "distributed by default." The runtime gives you
**transparency and primitives — not consistency, not partition-handling, not security.**

### Network partitions / split-brain — distribution does not solve CAP

- The BEAM treats an unreachable node as **dead** (it cannot distinguish "node crashed" from
  "network split"). That's a deliberate, pragmatic choice, but it means partitions are a
  first-class concern you must design for. As LYSE puts it: "There is sadly no way to keep an
  application alive and correct at the same time during a netsplit." (CAP, restated.)
- **`global` can become inconsistent.** Official docs, verbatim: "A network of overlapping
  partitions might cause the internal state of `global` to become inconsistent. Such an
  inconsistency can remain even after such partitions have been brought together to form a
  fully connected network again." Since OTP 25 the `prevent_overlapping_partitions` kernel
  parameter mitigates this by actively disconnecting nodes that report lost connections; the
  docs warn that `global`'s services "will [not] be reliably delivered unless both… 
  `connect_all` and `prevent_overlapping_partitions` are enabled." (erlang.org, *global*.)
- **`mnesia` split-brain.** On a partition, both sides keep accepting writes; on healing,
  `mnesia` logs `{inconsistent_database, running_partitioned_network, Node}` and **leaves
  the choice of which side "wins" to the application** — reconciling/merging is explicitly
  out of scope for mnesia. This is the classic reason people reach for external CP stores
  for data that must not diverge. (mnesia docs / community accounts.)
- Takeaway: the cluster-wide singleton ("one global process") and "replicate everything with
  mnesia" patterns are attractive *until* a partition. You still need to pick your CAP
  trade-off, and BEAM idioms like CRDT-based state (Phoenix Presence, Horde) exist precisely
  because the runtime won't make that choice for you.

### Security — a distributed Erlang cluster is a single trust domain

This is the caveat most likely to surprise JVM developers, and it is well documented:

- **The cookie is not real auth.** "There is no authentication built into the default
  distribution protocol, merely a 'cookie' mechanism that prevents the unintentional mixing
  of Erlang clusters on the same network." (erlang.org, *Secure Coding*.)
- **Traffic is unencrypted by default.** Default distribution uses "an unencrypted TCP
  connection" and "should only be used in a trusted network." Term data crosses the wire in
  the clear (a variant of External Term Format). (erlang.org, *Secure Coding*.)
- **Connecting a node = owning the cluster.** "All nodes admitted into an Erlang cluster
  must be trusted. Once a node is connected to the cluster, it gains complete access to the
  resources and operations of all other nodes." A connected peer can spawn processes and run
  arbitrary code on every other node — hence: **the whole cluster is one trust domain.**
  (erlang.org, *Secure Coding*.) The `distributed.html` reference is equally blunt: starting
  a distributed node without `-proto_dist inet_tls` "will expose the node to attacks that may
  give the attacker complete access to the node and by extension the cluster."
- **TLS distribution exists but is opt-in.** You can run distribution over TLS with
  `-proto_dist inet_tls` (module `inet_tls_dist`), ideally with client-certificate
  verification — but the default module is `inet_tcp_dist`, so TLS is a "deliberate,
  consistent configuration across all nodes," never automatic. (erlang.org, *Using TLS for
  Erlang Distribution*.)
- Practical guidance: keep distribution on a private network, firewall `epmd` (and the
  distribution ports), use TLS distribution for any untrusted path, and never expose disterl
  to the public internet.

### "Primitives, not correctness"

Bundle the above into one slide-ready idea: **"distributed by default" means the wiring and
the API are free; the hard parts — consistency under partition, conflict resolution, and a
real security boundary — are still yours to design.** The BEAM removes the *plumbing* tax,
not the *distributed-systems* tax.

## Why it matters for the talk / what JVM folks can learn

- **The contrast in one line:** the JVM is **not** distributed by default. To get clustering
  you reach for a library/framework — **Akka/Pekko Cluster** (gossip membership + phi-accrual
  failure detection + cluster sharding), Akka/Pekko **Remoting** (Artery, over TCP/Aeron),
  **gRPC**/Netty for service-to-service RPC, **Hazelcast** for distributed data structures.
  Distribution is bolted on; on the BEAM it is a runtime primitive baked into the same
  message-passing model you already use for concurrency.
- **Location transparency is the lesson worth stealing.** The BEAM proves that "the unit of
  concurrency" and "the unit of distribution" can be the same abstraction (a process with a
  mailbox). Java's virtual threads (Project Loom) closed much of the *concurrency* gap, but
  there is still no built-in *location-transparent* messaging — that's exactly the niche
  Akka/Pekko fill, and it's instructive that the JVM ecosystem reinvented the actor model to
  get it. (Akka Cluster's gossip topology is, notably, **not** a full mesh — each node
  monitors a ring of ~9 others — which is one way it scales past disterl's mesh limit.)
- **But teach the caveats too — that's what makes it credible.** A balanced talk says: the
  BEAM gives JVM developers a *better default* (transparency, links/monitors across the
  network, OTP building blocks) **and** a clear warning that defaults don't equal
  correctness or security. The cookie-is-not-auth and global-under-partition stories are
  great, honest, memorable beats that pre-empt the "isn't that magic just hiding the hard
  parts?" objection.
- **Right-sizing for the audience.** Most JVMers in the room build "modest-scale" systems —
  a handful to a few dozen nodes. That is *exactly* where disterl's full mesh shines: it's
  effectively free, no extra infrastructure, no service mesh, no separate RPC layer. The
  60–200-node ceiling and partisan are worth one honest sentence, not a deep dive — the
  point is "you almost certainly won't hit the limit, and there's a known path if you do."

## Sources

Primary / official:

- **erlang.org — Distributed Erlang (System Documentation):**
  https://www.erlang.org/doc/system/distributed.html — definitions of node, long/short
  names, magic cookie comparison, transitive (`-connect_all`) mesh, hidden nodes, `spawn/4`,
  `node()`/`nodes()`, `net_kernel`, epmd, and the `-proto_dist inet_tls` security warning.
- **erlang.org — Secure Coding Guidelines:**
  https://www.erlang.org/doc/system/secure_coding.html — the authoritative "cookie is not
  authentication," "unencrypted TCP," "once connected, complete access to all other nodes,"
  single-trust-domain, and epmd info-leak statements (all quoted verbatim above).
- **erlang.org — `global` (kernel):**
  https://www.erlang.org/doc/apps/kernel/global.html — three services (names, locks, mesh
  maintenance), the verbatim overlapping-partitions inconsistency warning, and
  `prevent_overlapping_partitions` (OTP 25+).
- **erlang.org — `pg` (kernel):** https://www.erlang.org/doc/man/pg.html — process groups,
  scopes, scalability vs `pg2`, no dependency on `global`.
- **erlang.org — Erlang Distribution over TLS (ssl):**
  https://www.erlang.org/doc/apps/ssl/ssl_distribution.html — `inet_tls_dist` /
  `-proto_dist inet_tls`, default module is `inet_tcp_dist`, TLS is opt-in and must be set on
  all nodes.

Reference / community:

- **Learn You Some Erlang — Distribunomicon:**
  https://learnyousomeerlang.com/distribunomicon — nodes, epmd, the "cookie is a joke as
  security" framing, full-mesh "everyone connects to everyone," location transparency
  (remote send / `spawn` / `rpc`), hidden nodes, tick time/heartbeats, CAP/netsplit
  ("$1000 → $2000" split-brain illustration), `net_kernel`/`global`/`rpc` overviews.

Gleam-side wrappers (verified via current Hex/GitHub, June 2026):

- **`glyn`:** https://github.com/mbuhot/glyn and https://hexdocs.pm/glyn/ — type-safe pub/sub +
  registry for Gleam actors, built on the same `syn` library, with distributed clustering.
- **`glixir`:** https://hexdocs.pm/glixir/ — type-safe OTP interop (call Elixir/Erlang
  GenServers, Supervisors, Registry from Gleam), for distribution helpers Gleam doesn't wrap yet.
- **Gleam externals/FFI:** https://gleam.run/documentation/externals/ — basis for calling the
  Erlang/Elixir distribution primitives and libraries directly from Gleam.

Scaling / alternatives:

- **partisan (lasp-lang) — README / hexdocs:** https://github.com/lasp-lang/partisan and
  https://hexdocs.pm/partisan/readme.html — the **"between 60 and 200 nodes"** disterl limit,
  full-mesh + single-TCP-connection + head-of-line-blocking critique, and pluggable
  topologies (full mesh, HyParView, client-server, static).
- **Meiklejohn & Miller — *Partisan: Enabling Cloud-Scale Erlang Applications* (arXiv
  1802.02652):** https://arxiv.org/abs/1802.02652 — topology-agnostic distribution; reported
  up to 18x / 30x / 13.5x improvements and "scale to clusters of thousands of nodes."
- **Chechina et al. — *Scaling Reliably: Improving the Scalability of the Erlang Distributed
  Actor Platform* (arXiv 1704.07234):** https://arxiv.org/abs/1704.07234 — global recovery
  data "dramatically limits scalability"; SD Erlang network partitioning improves benchmarks
  "above 80 hosts." (Abstract retrieved; full-PDF parse failed — see unverified claims.)

JVM integration:

- **erlang.org — JInterface User's Guide:**
  https://www.erlang.org/doc/apps/jinterface/jinterface_users_guide.html — official docs for
  `OtpNode`, `OtpMbox`, term encoding/decoding, cookie auth, and the full Java distribution
  protocol implementation. *(Fetched directly.)*

JVM contrast:

- **Akka Remoting (Artery):** https://doc.akka.io/libraries/akka-core/current/remoting-artery.html
  — actors on different JVMs communicate transparently; transport over TCP/Aeron.
- **Akka Cluster — Specification / Membership:**
  https://doc.akka.io/libraries/akka-core/current/typed/cluster-concepts.html and
  https://doc.akka.io/libraries/akka-core/current/typed/cluster-membership.html — gossip-based
  membership, phi-accrual failure detector, each node monitors a ring of ~9 others (not a
  full mesh).
- **Apache Pekko — Artery Remoting:** https://pekko.apache.org/docs/pekko/1.1/remoting-artery.html
  — the Apache-licensed Akka fork; gRPC offered as a separate, more explicit/decoupled
  alternative to remoting.

### Unverified / flagged claims

- **Per-benchmark degradation node counts** ("~40 nodes for the 5M orbit, ~140 for the 2M
  orbit," and "linear up to 150 nodes / 1200 cores"): these appear in *search-result
  summaries* of the SD Erlang work, but I could only verify the abstract of arXiv 1704.07234
  directly (the PDF failed to parse). The abstract confirms the *direction* ("global recovery
  data dramatically limits scalability"; improvement "above 80 hosts") but **not** the exact
  per-orbit figures. Treat those specific numbers as not independently confirmed.
- **"~2.6 KB / millions of processes" and WhatsApp 2M connections** are concurrency facts
  covered in `03-concurrency.md`, not re-verified here.
- **partisan performance multipliers (18x/30x/13.5x)** come from the paper's abstract; I did
  not reproduce the benchmark methodology, so cite them as the authors' reported figures, not
  independent measurements.
- The **"60–200 nodes" limit** is sourced to the partisan README's framing; it is a
  practitioner guideline (workload-dependent), not a value from the core OTP docs.
