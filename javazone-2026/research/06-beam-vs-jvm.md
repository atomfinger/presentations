# BEAM vs JVM

*Reference doc for the JavaZone 2026 talk "Gleam and BEAM: Looking beyond the JVM." Audience is JVM/Java developers building modest-scale software who respect the JVM. The goal is a fair, synthesis-level comparison — not a hit piece — that survives a skeptical room.*

---

## TL;DR

- **These are two excellent runtimes optimized for different things.** The JVM is a throughput-and-ecosystem powerhouse with a world-class JIT and three decades of libraries, tooling, and talent. The BEAM (Erlang's VM, also runs Elixir and Gleam) is a concurrency-and-resilience powerhouse built for systems that must stay up and stay responsive.
- **One-line summary:** the JVM is built for *parallelism and raw speed*; the BEAM is built for *massive concurrency, fault isolation, and predictable latency*. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/))
- **The BEAM wins** on cheap concurrency (millions of isolated processes), fault isolation + supervision ("let it crash"), predictable tail latency (no global stop-the-world GC), distribution as a built-in runtime primitive, and live introspection / hot code upgrade.
- **The JVM wins** on raw single-threaded and numeric throughput (C2/Graal JIT), the sheer size of its library/framework ecosystem, the talent pool, heavy data/ML/big-data tooling (Spark et al.), and decades of profiling/ops tooling. The BEAM is comparatively slow at number-crunching.
- **Crucial nuance for this audience:** "the JVM = big GC pauses" is dated. ZGC and Shenandoah deliver sub-millisecond pauses today. And Project Loom (virtual threads, finalized in Java 21) plus structured concurrency are the JVM converging on lightweight-concurrency ideas the BEAM has shipped since the 1980s–90s. Akka was itself directly inspired by Erlang.
- **The talk's payoff:** JVM developers can borrow BEAM *design philosophy* — design for failure + supervision instead of defensive coding, isolation over shared mutable state, valuing latency *consistency* not just peak throughput, and the actor model — without leaving the JVM.

---

## Side-by-side comparison

| Dimension | BEAM (Erlang/Elixir/Gleam) | JVM (Java/Kotlin/Scala) |
|---|---|---|
| **Concurrency model** | Lightweight *processes* (actors) scheduled by the VM, ~one scheduler thread per CPU core by default. Processes share no memory and communicate only by async message passing. Preemptive scheduling via a per-process *reduction* budget (~roughly one reduction per function call; a process is preempted after its budget, historically ~2000), so no single process can starve others. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/), [AppSignal](https://blog.appsignal.com/2024/04/23/deep-diving-into-the-erlang-scheduler.html), [theBeamBook](https://github.com/happi/theBeamBook/blob/master/chapters/scheduling.asciidoc)) | Historically OS-mapped *platform threads* (1:1), scheduled by the OS, sharing a common heap and coordinated via locks/synchronization. **Java 21 added virtual threads** (Project Loom): M:N lightweight threads scheduled by the JVM onto a work-stealing carrier pool — conceptually close to BEAM processes. ([JEP 444 via marcnuri.com](https://blog.marcnuri.com/java-virtual-threads-project-loom-complete-guide)) |
| **Memory & GC** | **Per-process isolated heaps.** Each process is GC'd independently, on its own, without stopping other processes — so there is no global stop-the-world pause; collection cost is proportional to one small process's live set. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/)) | **Shared heap** across all threads, with mature generational collectors. G1 is the default; **ZGC and Shenandoah** are mostly-concurrent collectors offering sub-millisecond max pauses largely independent of heap size. ([Per Liden / ZGC](https://malloc.se/blog/zgc-jdk16), [Red Hat / Shenandoah](https://developers.redhat.com/articles/2021/09/16/shenandoah-openjdk-17-sub-millisecond-gc-pauses)) |
| **Fault model** | **Process isolation + supervision trees.** A crashing process dies alone; a *supervisor* restarts it to a known-good state ("let it crash"). Errors are recovered structurally rather than handled defensively everywhere. ([Wikipedia: Erlang](https://en.wikipedia.org/wiki/Erlang_(programming_language)), [Verraes](https://verraes.net/2014/12/erlang-let-it-crash/)) | Exceptions + try/catch, thread-level error handling, and libraries (resilience4j, circuit breakers, retries, bulkheads) layered on top. Isolation is a discipline/library concern, not a runtime guarantee — an uncaught error can corrupt shared mutable state. |
| **Distribution** | **Built into the runtime.** Distributed Erlang lets a program span multiple nodes/machines with transparent message passing; arguably the only widely used VM with a built-in distribution model at scale. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/)) | Provided by libraries/frameworks: Akka/Pekko (cluster + actors), gRPC, message brokers, etc. Powerful and mature, but distribution is opt-in tooling rather than a language/runtime primitive. |
| **Latency vs throughput** | Optimized for **consistent low latency / soft real-time fairness.** Preemptive per-process scheduling + per-process GC keep tail latency predictable under heavy concurrency. Lower raw single-thread throughput. | Optimized for **very high raw throughput.** The JIT produces excellent peak performance; modern low-pause GCs have closed much of the historical tail-latency gap. |
| **Hot code upgrade** | **First-class.** Release upgrades (relups) let a running system swap modules and migrate state with zero downtime — born from telecom switches that could not be taken offline. Powerful but operationally fiddly; many modern shops use blue/green or rolling deploys instead. ([erlang.org release handling](https://www.erlang.org/doc/system/release_handling.html), [Elixir `mix release` docs](https://hexdocs.pm/mix/Mix.Tasks.Release.html)) | Limited. HotSwap class redefinition exists mainly for debugging (method bodies) and is not a production zero-downtime upgrade mechanism. Production updates rely on rolling/blue-green deploys and orchestration. |
| **Tooling & observability** | Strong **live** introspection: `observer`, `recon`, and built-in tracing let you inspect and trace a *running* production node — process counts, message queues, memory, live function tracing — without a restart. | Strong, mature, decades-deep: JFR (Flight Recorder), async-profiler, JMX, plus the broad APM ecosystem. Excellent profiling/ops tooling; live in-process tracing is less of a first-class runtime feature than on the BEAM. |
| **Ecosystem & libraries** | Smaller. OTP is superb for its domain; the surrounding library/framework universe is far smaller than the JVM's. | **Vastly larger.** Enormous library/framework ecosystem, Maven Central, frameworks for nearly everything, and a huge hiring pool. |
| **Typical CPU performance** | Comparatively **slow at number-crunching**; the BEAM is not competitive for heavy raw arithmetic. Mitigated with NIFs (native code) for hot numeric paths. ([arXiv ffl-erl](https://arxiv.org/pdf/1808.08143)) | **Much faster** for CPU-bound, single-threaded, numeric work thanks to the C2/Graal JIT. This is a clear JVM strength. |

---

## Where the JVM wins

Be honest and specific — these are real, durable advantages, not legacy baggage:

1. **Raw single-threaded / CPU-bound throughput and numeric performance.** The HotSpot C2 JIT (and GraalVM's JIT) aggressively optimize hot paths into highly tuned machine code, with tiered compilation that starts fast (C1) and recompiles hot methods at the top tier. ([w3computing](https://www.w3computing.com/articles/jvm-jit-compiler-deep-dive-c1-c2-tiered-compilation/)) For heavy arithmetic the BEAM is simply not in the same class — academic benchmarks note the Erlang VM "does not perform competitively for heavy numeric calculations." ([arXiv ffl-erl](https://arxiv.org/pdf/1808.08143))
2. **Mature, sophisticated JIT.** C2 and Graal represent decades of compiler engineering — escape analysis, inlining, speculative optimization, deoptimization. This is hard-won and hard to replicate.
3. **Enormous library & framework ecosystem.** Spring, Micronaut, Quarkus, Hibernate, Netty, and tens of thousands of mature libraries on Maven Central. For most "I need a library for X" problems, the JVM already has several battle-tested options.
4. **Massive talent pool.** Hiring experienced JVM developers is far easier than hiring Erlang/Elixir/Gleam developers.
5. **Heavy data / ML / big-data tooling.** Apache Spark, Flink, Kafka (JVM-based), Hadoop-era tooling, and the broad JVM data ecosystem. For large-scale batch/analytics/ML pipelines this is a JVM stronghold.
6. **Decades of profiling and ops tooling.** JFR, async-profiler, JMX, plus a deep commercial APM ecosystem and accumulated operational know-how.

**Bottom line:** if your bottleneck is CPU-bound computation, numeric/data crunching, or you need a specific mature library and a large hiring pool, the JVM is very often the right call.

---

## Where the BEAM wins

1. **Massive, cheap concurrency.** Spawning a BEAM process is cheap and the runtime routinely runs hundreds of thousands to millions of them. Real-world proof points: Discord scaled Elixir to ~5,000,000 concurrent users, with individual session VMs holding up to ~500,000 live sessions. ([Discord blog](https://discord.com/blog/how-discord-scaled-elixir-to-5-000-000-concurrent-users)) (Note: the JVM is now competitive on lightweight concurrency *count* via virtual threads — see Caveats.)
2. **Fault isolation & self-healing.** Process isolation + supervision trees mean a failure is contained to one process and recovered structurally by restarting to a known state, rather than risking corruption of shared state. ([Verraes](https://verraes.net/2014/12/erlang-let-it-crash/), [Wikipedia: Erlang](https://en.wikipedia.org/wiki/Erlang_(programming_language)))
3. **Predictable tail latency / no global GC pause.** Per-process isolated heaps mean GC happens per small process and never stops the whole world; combined with preemptive fair scheduling, tail latency stays predictable under load. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/))
4. **Distribution as a runtime primitive.** Multi-node clustering and transparent inter-node messaging are built into the runtime, not bolted on. ([Erlang Solutions](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/))
5. **Live introspection & hot-patching.** Inspect and trace a running production node (`observer`/`recon`/tracing); upgrade code in place via relups when needed. ([erlang.org release handling](https://www.erlang.org/doc/system/release_handling.html))
6. **Soft real-time fairness.** Preemptive reduction-based scheduling guarantees no single process can monopolize a core, so the system stays responsive even with many busy processes. ([theBeamBook](https://github.com/happi/theBeamBook/blob/master/chapters/scheduling.asciidoc), [AppSignal](https://blog.appsignal.com/2024/04/23/deep-diving-into-the-erlang-scheduler.html))

**Bottom line:** if your problem is "lots of concurrent connections/stateful entities that must stay responsive and keep running through partial failures" (chat, messaging, telecom, real-time, IoT, soft real-time backends), the BEAM is purpose-built for it.

---

## Numbers & benchmarks

*Sourced figures only. Where a claim is qualitative I keep it qualitative on purpose.*

**GC pauses (JVM low-latency collectors):**
- **ZGC, JDK 16+:** average GC pause ~0.05 ms (50 µs), max ~0.5 ms (500 µs), with an explicit design goal that a pause should never exceed 1 ms — achieved via concurrent thread-stack scanning (Stack Watermark Barrier). Pause times are largely independent of heap, live-set, and root-set size. ([Per Liden / malloc.se](https://malloc.se/blog/zgc-jdk16)) ZGC targets heaps from 8 MB up to 16 TB. ([OpenJDK ZGC project page — see caveat below on access](https://openjdk.org/projects/zgc/))
- **Shenandoah, JDK 17:** delivers reliable sub-millisecond pauses via concurrent thread-stack processing; e.g. init-mark pauses fell from ~421 µs (JDK 11) to ~63 µs (JDK 17), and pause times are independent of heap size. ([Red Hat Developer](https://developers.redhat.com/articles/2021/09/16/shenandoah-openjdk-17-sub-millisecond-gc-pauses))

**Virtual threads / Loom (JVM lightweight concurrency):**
- Virtual threads finalized in **Java 21** (JEP 444, GA Sept 2023). A platform thread reserves ~1 MB of stack by default; a virtual thread's stack is heap-allocated and grows on demand from a tiny initial footprint, so a single server can host on the order of a million virtual threads where platform threads would be limited to thousands. ([marcnuri.com summarizing JEP 444](https://blog.marcnuri.com/java-virtual-threads-project-loom-complete-guide))

**BEAM concurrency at scale (real-world proof points, not lab benchmarks):**
- Discord: scaled Elixir to **~5,000,000 concurrent users**, with a single session VM holding **up to ~500,000 live sessions**. ([Discord blog](https://discord.com/blog/how-discord-scaled-elixir-to-5-000-000-concurrent-users))
- BEAM process footprint is small (commonly cited around a few KB per process); the official Erlang docs describe processes as memory-isolated and message-passing but do **not** themselves publish a per-process byte figure — treat the "~2–3 KB" number as community/secondary, not an official Erlang.org figure (see Caveats). ([erlang.org concurrency docs](https://www.erlang.org/doc/system/conc_prog.html))

**Numeric performance:**
- Academic benchmarking notes the Erlang VM "is usually less efficient than the Java VM when it comes to raw arithmetic," with native-compilation/NIF approaches used to close the gap for hot paths. ([arXiv ffl-erl](https://arxiv.org/pdf/1808.08143)) Treat exact ratios as workload-dependent; the directional claim (JVM faster at number-crunching) is robust.

---

## Nuance & caveats

- **"JVM = big stop-the-world GC pauses" is dated.** With ZGC or Shenandoah, max pauses are sub-millisecond and largely heap-size-independent. ([Per Liden](https://malloc.se/blog/zgc-jdk16), [Red Hat](https://developers.redhat.com/articles/2021/09/16/shenandoah-openjdk-17-sub-millisecond-gc-pauses)) The honest framing is *architectural*: the JVM gives you a low-pause *whole-heap* collector that you select and tune; the BEAM gives you per-process collection so the question of a global pause largely doesn't arise. Both reach "good tail latency," by different routes — and the JVM's default G1 still has more visible pauses than ZGC/Shenandoah, so the comparison depends on which collector is configured.
- **Loom is genuine convergence, with limits.** Virtual threads give the JVM cheap, numerous threads — closing the *concurrency-count* gap with BEAM processes. But virtual threads still **share a heap and share mutable state**; they do not give you the BEAM's *isolation* or *supervision* semantics out of the box. So Loom narrows the concurrency-scaling gap, not the fault-isolation gap. ([marcnuri.com / JEP 444](https://blog.marcnuri.com/java-virtual-threads-project-loom-complete-guide))
- **Structured concurrency is still preview.** Java's structured concurrency (`StructuredTaskScope`) was still in preview as of JDK 25 (JEP 505, fifth preview). It's maturing, not yet final. ([InfoQ on JEP 505](https://www.infoq.com/news/2025/05/jep-505-concurrency-preview-5/), [JEP 505 — see access caveat](https://openjdk.org/jeps/505))
- **Hot code upgrade is powerful but niche in practice.** Relups are real and uniquely capable, but they're operationally fiddly; many modern BEAM shops deploy via blue/green or rolling deploys and use hot upgrade rarely. Don't oversell it as an everyday workflow. ([Elixir `mix release` docs](https://hexdocs.pm/mix/Mix.Tasks.Release.html))
- **Benchmarks are workload-dependent.** "BEAM wins concurrency, JVM wins CPU" is directionally true and well-supported, but specific numbers swing hugely with workload, JDK/OTP version, GC choice, and code quality. Cite the *direction* confidently; treat exact ratios as illustrative.
- **Both ecosystems are moving.** The JVM is adopting lightweight concurrency (Loom) and low-pause GC (ZGC/Shenandoah); the BEAM gained the JIT in OTP 24+ (improving throughput). Avoid framing either as standing still.
- **Per-process KB figure is secondary-sourced.** The widely repeated "~2.5 KB per process" comes from community/blog sources, not from the official Erlang documentation we retrieved. Present it as "small, a few KB" rather than a precise authoritative number.

---

## Why it matters for the talk / what JVM folks can learn

The payoff isn't "abandon the JVM." Most of this room can stay on the JVM and still steal the BEAM's best *ideas*:

1. **Design for failure — "let it crash" + supervision — instead of defensive coding.** Stop sprinkling speculative try/catch everywhere. Isolate a unit of work, let it fail cleanly, and have a supervisor restart it to a known-good state. ([Verraes](https://verraes.net/2014/12/erlang-let-it-crash/)) On the JVM you can approximate this with supervised actors (Akka/Pekko), bulkheads, and resilience4j patterns.
2. **Prefer isolation over shared mutable state.** The BEAM's superpower is that processes share nothing and communicate by messages, which removes whole classes of concurrency bugs. Even with virtual threads, the JVM still shares a heap — so the *discipline* of message-passing and ownership boundaries is something to adopt deliberately.
3. **Value latency *consistency*, not just peak throughput.** Modest-scale services often care more about predictable p99 than maximum req/s. That reframing — measure and design for tail latency — is one of the BEAM community's most transferable lessons, and on the JVM it now has a concrete answer: choose a low-pause GC (ZGC/Shenandoah) when latency consistency matters.
4. **Learn the actor model.** It's a clean mental model for concurrency that the JVM can use directly via Akka/Pekko.
5. **Recognize the convergence — and credit the lineage.** **Akka was directly inspired by Erlang.** Akka's creator, Jonas Bonér, built it (starting ~2009, first release Jan 2010) explicitly "inspired by the Erlang programming language's library support for writing highly concurrent, distributed, and event-driven applications," and Akka's actor API borrowed syntax from Erlang. ([Wikipedia: Akka](https://en.wikipedia.org/wiki/Akka_(toolkit))) And **Project Loom (virtual threads, Java 21) plus structured concurrency are the mainstream JVM converging on lightweight-concurrency ideas the BEAM has had for ~30 years.** That's the honest, fair frame for a JVM audience: the BEAM isn't a competitor to dunk on — it's a 30-year-old proving ground for ideas the JVM is now adopting, and there's still more worth borrowing.

6. **JInterface: you don't have to choose all-at-once.** JInterface — an official Erlang/OTP
   application shipped with every OTP install — lets a Java process join a BEAM cluster as a
   named node and exchange Erlang messages with Gleam or Erlang processes over standard Erlang
   distribution. No REST layer, no broker in the middle. This is the **incremental migration
   story**: a team can keep a legacy Java service running, stand up a new Gleam service beside
   it, and have them message-pass directly — migrating piece by piece. The API is low-level
   (you hand-construct Erlang terms in Java and there is no Java supervision tree), so treat it
   as a narrow seam rather than a general architecture, but it cleanly removes the "it's
   all-or-nothing" objection from a JVM audience. ([erlang.org JInterface User's Guide](https://www.erlang.org/doc/apps/jinterface/jinterface_users_guide.html))

**The fair closing line for the room:** the JVM is a fantastic runtime that's actively getting better at exactly the things the BEAM has always been good at. Looking at the BEAM isn't disloyalty to the JVM — it's looking at where good ideas come from.

---

## Sources

*Only URLs actually retrieved or returned in search are listed. Annotated with what each supports and a reliability note.*

**Primary / authoritative**
- [Per Liden — "ZGC | What's new in JDK 16" (malloc.se)](https://malloc.se/blog/zgc-jdk16) — Authoritative (Per Liden led ZGC). Source for ZGC ~50 µs avg / ~500 µs max pause and the sub-1 ms goal via concurrent stack scanning. *Fetched directly.*
- [Red Hat Developer — "Shenandoah in OpenJDK 17: Sub-millisecond GC pauses"](https://developers.redhat.com/articles/2021/09/16/shenandoah-openjdk-17-sub-millisecond-gc-pauses) — Authoritative (Red Hat maintains Shenandoah). Source for Shenandoah sub-ms pauses and init-mark 421 µs → 63 µs. *Via search result summary; not directly fetched.*
- [erlang.org — Concurrent Programming docs](https://www.erlang.org/doc/system/conc_prog.html) — Official. Confirms processes share no data and communicate by message passing; does NOT publish a per-process byte figure. *Fetched directly.*
- [erlang.org — Release Handling docs](https://www.erlang.org/doc/system/release_handling.html) — Official. Source for relup / hot release upgrade mechanics. *Via search result; URL surfaced in search, not directly fetched.*
- [theBeamBook — scheduling chapter (GitHub)](https://github.com/happi/theBeamBook/blob/master/chapters/scheduling.asciidoc) — The BEAM Book, widely regarded reference. Supports preemptive reduction-based per-core scheduling. *Via search result; not directly fetched.*
- [Discord Engineering — "How Discord Scaled Elixir to 5,000,000 Concurrent Users"](https://discord.com/blog/how-discord-scaled-elixir-to-5-000-000-concurrent-users) — Primary engineering blog. Source for ~5M concurrent users and ~500k sessions per VM. *Fetched directly.*
- [Wikipedia — Akka (toolkit)](https://en.wikipedia.org/wiki/Akka_(toolkit)) — Source for "Akka inspired by Erlang," Jonas Bonér, ~2009/Jan 2010, API borrowed from Erlang. *Fetched directly.*
- [Wikipedia — Erlang (programming language)](https://en.wikipedia.org/wiki/Erlang_(programming_language)) — Source for "let it crash," supervision trees, Armstrong/Virding/Williams 1986. *Via search result summary.*

**Reputable secondary / explanatory**
- [Erlang Solutions — "BEAM and JVM virtual machines: comparing and contrasting"](https://www.erlang-solutions.com/blog/beam-jvm-virtual-machines-comparing-and-contrasting/) — Vendor blog but technically solid and directly on-topic. Source for "JVM built for parallelism, BEAM for concurrency," per-process GC with no stop-the-world, built-in distribution. Note: vendor has a pro-BEAM lean — used for architecture claims, not as a neutral benchmark. *Fetched directly.*
- [AppSignal — "Deep Diving Into the Erlang Scheduler"](https://blog.appsignal.com/2024/04/23/deep-diving-into-the-erlang-scheduler.html) — Supports one-scheduler-per-core and reduction-based preemption. *Via search result.*
- [marcnuri.com — "Java Virtual Threads Complete Guide (Project Loom)"](https://blog.marcnuri.com/java-virtual-threads-project-loom-complete-guide) — Summarizes JEP 444: virtual threads final in Java 21, ~1 MB platform stack vs heap-allocated growing virtual stack, M:N scheduling, ~1M virtual threads. *Fetched directly.* (Secondary summary of the official JEP — see caveat.)
- [InfoQ — "JEP 505 Delivers Fifth Preview of Structured Concurrency"](https://www.infoq.com/news/2025/05/jep-505-concurrency-preview-5/) — Source for structured concurrency still in preview (JEP 505) as of JDK 25. *Via search result.*
- [w3computing — "JVM JIT Compiler Deep Dive: C1, C2, and Tiered Compilation"](https://www.w3computing.com/articles/jvm-jit-compiler-deep-dive-c1-c2-tiered-compilation/) — Supports C2/tiered-compilation as the source of JVM raw throughput. *Via search result.*
- [Elixir — `mix release` documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html) — Elixir's official release tooling, which does **not** support hot code upgrades out of the box and points users to rolling/blue-green deploys instead — primary support for the "relups are powerful but niche in practice" caveat. *Fetched directly.*
- [Verraes — "Let it crash" (Erlang error handling)](https://verraes.net/2014/12/erlang-let-it-crash/) — Explains let-it-crash + supervision philosophy. *Via search result.*
- [arXiv — "Functional Federated Learning in Erlang (ffl-erl)"](https://arxiv.org/pdf/1808.08143) — Academic source for "Erlang VM less efficient than JVM at raw arithmetic" and NIF/native mitigation. *Via search result.*
- [erlang.org — JInterface User's Guide](https://www.erlang.org/doc/apps/jinterface/jinterface_users_guide.html) — Official docs for JInterface (`OtpNode`, `OtpMbox`, Erlang term encoding, cookie auth); source for the "Java as a BEAM node / incremental migration" talking point. *Fetched directly.*

**Surfaced in search but blocked (403) — NOT directly verified by me**
- [OpenJDK — ZGC project page](https://openjdk.org/projects/zgc/) — Would be the canonical source for ZGC's 8 MB–16 TB heap range and sub-ms goal. **openjdk.org returned HTTP 403 on fetch; the heap-range figure is corroborated by search summaries and the OpenJDK ZGC wiki, but I did not retrieve the official page directly.**
- [OpenJDK — JEP 505 (Structured Concurrency)](https://openjdk.org/jeps/505) and JEP 444 (Virtual Threads) — Canonical specs. **openjdk.org returned HTTP 403 on fetch; details here come from reputable secondary summaries (marcnuri.com, InfoQ), not the primary JEP pages.**

---

### Unverified / flagged claims (state these carefully on stage)

1. **Per-process memory "~2.5 KB":** community/blog figure; the official erlang.org docs we retrieved do not state a byte figure. Say "small, a few KB," not a precise authoritative number.
2. **ZGC 8 MB–16 TB heap range and JEP 444/505 specifics:** corroborated only via secondary sources because **openjdk.org returned 403** on direct fetch. The figures are widely repeated and consistent, but I could not confirm them against the primary OpenJDK pages.
3. **erlang.org release-handling page** and **theBeamBook scheduling chapter**: surfaced via search and their content matches well-established knowledge, but I did not fetch their full bodies directly — the supporting detail came from search-result summaries.
4. **WhatsApp "2 million connections per server" / "1 billion users, 50 engineers":** these popular figures appeared in search summaries (favtutor) but I did not verify them against a primary WhatsApp/Erlang source — I deliberately used the **Discord** numbers (primary engineering blog) instead. If you want a WhatsApp datapoint on stage, verify against the original WhatsApp/Rick Reed talk first.
5. Exact numeric-performance ratios are intentionally omitted — workload-dependent. The *direction* (JVM faster at number-crunching) is well-supported.
