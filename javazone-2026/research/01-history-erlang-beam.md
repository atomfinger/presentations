# History & Origins of Erlang and the BEAM

## TL;DR

Erlang was created at Ericsson's Computer Science Laboratory starting around 1986 by Joe Armstrong, Robert Virding, and Mike Williams to solve a hard telecom problem: phone switches that must handle massive concurrency, never go down, respond in soft real-time, and be upgraded *while running*. The language began as a Prolog interpreter, then moved to compiled abstract machines — JAM ("Joe's Abstract Machine"), the short-lived TEAM, and finally **BEAM** ("Bogdan's / Björn's Erlang Abstract Machine"), still the standard runtime today. Erlang ships with **OTP**, a battle-tested library of fault-tolerance design patterns (supervision trees, gen_server, etc.) that is arguably more important than the language itself. Erlang was banned internally at Ericsson in 1998, open-sourced that December, and the BEAM now hosts a family of languages — Erlang, Elixir, Gleam, LFE and more.

## Key facts & mechanics

### Ericsson origins (~1986 onward)
- Developed at the **Ericsson Computer Science Laboratory** by **Joe Armstrong, Robert Virding, and Mike Williams**, starting around **1986** (the language took shape roughly 1985–1989). Source: Wikipedia, HOPL "A History of Erlang."
- **The telecom problem it solved.** Erlang was built to program telephony switches, which imposed an unusual cluster of requirements simultaneously:
  - **Massive concurrency** — a switch handles huge numbers of simultaneous calls, each naturally modeled as its own lightweight process.
  - **High availability / fault tolerance** — switches are expected to run for years; a fault in one call must not take down the others. This drove the "let it crash" philosophy and process isolation (each process has its own memory; they communicate only by message passing).
  - **Soft real-time** — calls must be serviced within bounded latency (not *hard* real-time, but responsive and predictable; hence per-process garbage collection rather than global stop-the-world pauses).
  - **In-service / hot code upgrade** — you cannot take a national phone network offline to deploy a patch, so the runtime supports loading new code into a running system.
  - **Distribution** — switches are inherently distributed across nodes/hardware.
- **PLEX influence.** Early Erlang was influenced by **PLEX**, the proprietary language used in earlier Ericsson AXE exchanges (Wikipedia).

### Language lineage: Prolog → compiled
- **The initial version of Erlang was implemented in Prolog (1986)** and was strongly influenced by Prolog (pattern matching, the syntax of clauses, unification heritage). The Prolog interpreter was great for rapid experimentation but far too slow for production.
- "It soon became clear that Erlang needed to be at least **40 times faster** to be useful in real projects." (erlang.org BEAM compiler history)
- **JAM — "Joe's Abstract Machine" (1989).** The first compiled implementation. **Mike Williams wrote the runtime system in C, Joe Armstrong wrote the compiler, Robert Virding wrote the libraries.** JAM turned out to be **~70 times faster than the Prolog interpreter** (erlang.org BEAM compiler history; happihacking "Three Decades with Erlang").

### BEAM itself
- **TEAM — "Turbo Erlang Abstract Machine."** Created by **Bogumil "Bogdan" Hausman**, TEAM compiled Erlang to C and then through GCC. It was significantly faster than JAM for *small* projects, but compilation was very slow and the compiled code size was too large to be practical for *large* projects. (erlang.org)
- **BEAM — "Bogdan's Erlang Abstract Machine."** Hausman's next machine. Originally a **hybrid** that could execute both native code and threaded/interpreted code, so customers could compile time-critical modules to native code and everything else to threaded BEAM code. (erlang.org)
- **What "BEAM" stands for.** Originally **B**ogdan's **E**rlang **A**bstract **M**achine, after Bogumil "Bogdan" Hausman who wrote the original. Today it is more often glossed as **Björn's Erlang Abstract Machine**, after **Björn Gustavsson**, who wrote and long maintained the current version. The BEAM Book states both readings explicitly. (The BEAM Book; Wikipedia)
- **BEAM vs ERTS.** Strictly, BEAM is the *abstract machine / bytecode instruction set*. **ERTS (the Erlang Run-Time System)** is Ericsson's full industrial implementation around it (scheduler, memory management, I/O, distribution). In everyday speech "the BEAM" means the standard Erlang VM, which is what hosts Elixir, Gleam, etc. today. (The BEAM Book)
- Compiler evolution milestones: Björn Gustavsson joined the ERTS team in late 1996 (OTP R1B era); R5B introduced the modern BEAM file format; R6B added Robert Virding's improved pattern-matching compiler; R7B adopted **Core Erlang** as the standard intermediate representation — the pipeline most BEAM languages still target conceptually. (erlang.org BEAM compiler history)

### OTP — Open Telecom Platform
- **OTP is not the VM.** It is a collection of **libraries plus a set of design principles** for building fault-tolerant systems, layered on top of Erlang/BEAM. The name was originally a branding term, "Open Telecom Platform"; today people just say "Erlang/OTP" and the telecom framing is largely historical. (Wikipedia: Open Telecom Platform)
- **The core idea: supervision trees.** Program execution is organized into trees of processes. Leaf nodes are **workers** (do the actual work); internal nodes are **supervisors** that start, stop, and monitor their children and restart them on failure. This is the structural backbone of "let it crash."
- **Behaviours** are reusable patterns that factor out the generic part of common process types: `gen_server` (generic client/server), `gen_statem` / generic FSM (finite state machines), `gen_event` (event handlers/managers), `supervisor`, and `application` (package + supervision tree). You write the callback functions; OTP provides the proven, concurrency-correct skeleton.
- **Why it matters:** OTP is *the* reason Erlang's reliability claims are credible in practice. The fault-tolerance is not ad-hoc per project; it is encoded in shared, heavily-used library code.

### Open-sourcing (1998) and the internal Ericsson ban
This story is real and worth telling carefully — verified against Wikipedia and multiple accounts:
- **February 1998:** Ericsson Radio Systems **banned the in-house use of Erlang for new products**, preferring non-proprietary languages — the rationale being to avoid the cost of maintaining a language unique to Ericsson and instead ride the shared investment in mainstream languages.
- The ban pushed Armstrong and colleagues toward leaving. The team lobbied management to open-source the language; **Jane Walerud** did much of that lobbying.
- **December 1998:** Erlang was released as **open source**. Most of the Erlang team then resigned to form a new company, **Bluetail AB**.
- **Reversal:** Ericsson eventually relaxed the ban; Armstrong was re-hired by Ericsson in **2004**. (Note: the ban was a *policy against new in-house use*, not an erasure — Erlang continued to run in shipped products like the AXD301.)
- **License note:** Erlang/OTP is today distributed under the **Apache License 2.0** (it earlier used the Erlang Public License, an MPL derivative). The "open-sourced in December 1998" date refers to the original release, not the Apache relicensing.

### The name "Erlang"
- Attributed to **Bjarne Däcker** (head of the lab). Conventionally read as both a tribute to Danish mathematician/engineer **Agner Krarup Erlang** (founder of queueing/teletraffic theory — apt for telecom) and a syllabic abbreviation of **"Ericsson Language."** (Wikipedia)

### Languages on the BEAM today
- **Erlang** — the original; still the implementation language of ERTS/OTP itself.
- **Elixir** — created by **José Valim** (first releases ~2011–2012; v0.5.0 released May 2012). Ruby-flavored syntax, strong metaprogramming, its own tooling (Mix, Hex) and the Phoenix web framework. Now the most popular "new" BEAM language. (Wikipedia: Elixir)
- **Gleam** — created by **Louis Pilfold** (started 2016; **v1.0.0 released 4 March 2024**). A **statically typed** functional language with a type system inspired by Elm/OCaml/Rust; compiler/toolchain written in Rust; compiles to **both Erlang (BEAM) and JavaScript**; has its own type-safe OTP actor implementation. (Wikipedia: Gleam; gleam.run) **— this is the talk's headliner.**
- **LFE (Lisp Flavoured Erlang)** — a Lisp dialect on Core Erlang/BEAM, created by **Robert Virding** (one of Erlang's co-creators); first release 2008. (Wikipedia: LFE)
- **Others / niche:** Hamler (Haskell-like, statically typed), Caramel (OCaml→Erlang), Alpaca, plus **AtomVM** — a tiny VM that runs Erlang/Elixir/Gleam bytecode on microcontrollers and WebAssembly. (beam_languages list; atomvm.org)

## Numbers & benchmarks

- **JAM was ~70× faster than the Prolog interpreter**; the team's target was "at least 40× faster" to be production-viable. — [erlang.org BEAM compiler history](https://www.erlang.org/blog/beam-compiler-history/)
- **AXD301 codebase:** "over a million lines of Erlang" at the March 1998 launch (commonly cited as ~1.1–1.7M LOC; grew toward ~2.6M over its lifetime per secondary sources). Largest Erlang project of its era, **60+ Erlang developers**. — [ResearchGate: Industrial-Strength Functional Programming (Blau & Rooth)](https://www.researchgate.net/publication/238246524_Industrial-Strength_Functional_programming_Experiences_with_the_Ericsson_AXD301_Project); secondary summaries.
- **Erlang-to-C density:** Armstrong's rule of thumb was **~1 line of Erlang ≈ ~5 lines of C** (so the AXD301 would have been several million LOC in C). — attributed to Armstrong; widely cited, treat as a heuristic not a measurement.
- **The "nine nines" figure: 99.9999999% availability ≈ 31 ms of downtime per year.** For calibration: 5 nines ≈ 5.2 minutes/year, 7 nines is "almost unachievable." — see Nuance section; figures from Armstrong's LL2/MIT talk and the pragprog article, reproduced in Cronqvist's "The nine nines."
- **AXD301 / BT deployment (from the Ericsson marketing slide reproduced by Cronqvist):** 14 nodes carrying live traffic (Sept 2002, of a planned 23), "99,9999999% availability," **30–40 million calls per week per node**, billed as the world's largest telephony-over-ATM network. — [Cronqvist, "The nine nines"](https://www.erlang-factory.com/upload/presentations/243/ErlangFactorySFBay2010-MatsCronqvist.pdf)

## Nuance & caveats

### The "nine nines" claim — handle with care (do NOT state as flat fact)
This is the single most-repeated and most-misunderstood Erlang statistic. Here is what the evidence actually supports:

- **What was claimed:** 99.9999999% (nine nines) availability for the Ericsson **AXD301 ATM switch**, popularized in Joe Armstrong's talks/writing (his LL2 MIT talk and a Pragmatic Programmers article both contain the "nine nines / 31 ms a year" framing).
- **Armstrong himself flagged it as soft evidence.** In his 2003 PhD thesis, *Making reliable distributed systems in the presence of software errors*, he wrote (verbatim):
  > "Evidence for the long-term operational stability of the system had also not been collected in any systematic way. For the Ericsson AXD301 the only information on the long-term stability of the system came from a PowerPoint presentation showing some figures claiming that a major customer had run an 11 node system with a 99.9999999% reliability, though how these figure had been obtained was not documented."
- **A first-hand skeptic.** **Mats Cronqvist**, who says he was a **system architect/troubleshooter on the AXD301 project**, gave a talk literally titled *"The nine nines"* (Erlang Factory SF Bay, 2010). His key points:
  - The number came from the **customer (British Telecom)**, claiming nine-nines service availability **integrated over ~5 node-years** (note: that is *node-years*, a far smaller denominator than "the system over its whole life").
  - "As far as I know, **no one in the AXD 301 project claimed that this was normal, or even possible**."
  - **"For the record, Joe Armstrong was not part of the AXD 301 team."**
  - He calls the headline claim **"pretty bogus"** because: there was **much more C than Erlang** in the system; during the measured window there were **no restarts and no upgrades**; and the functionality was very well defined (i.e., not a fully general workload).
  - **But** — and this matters for an honest talk — he also says the system **was very reliable, and "compared to similar systems, it was amazingly reliable."** He just couldn't find a publicly verifiable reference for the exact figure.
- **Honest framing for slides:** Don't say "Erlang gives you nine nines." Say something like: *"Ericsson's AXD301 became famous for a 99.9999999% availability claim — about 31 ms of downtime a year. The number is contested: it came from a customer slide measured over a limited node-years window, the system was mostly C, and even Armstrong's own thesis calls the evidence undocumented. What's defensible is that it was an unusually reliable telecom system, and the architecture behind it — process isolation, supervision, OTP — is the real lesson."*

### Other myths / qualifications
- **"BEAM = the only thing that made AXD301 reliable" is wrong.** Per the people who built it, hardware engineering, the C layer, OS (Solaris), OTP, and disciplined project management all contributed. BEAM was necessary, not sufficient.
- **The productivity-multiplier claim was also softened.** Internal Ericsson claims of huge productivity gains from Erlang were controversial; the figure was reportedly downgraded toward a factor of ~3 — "sufficiently high to be impressive and sufficiently low to be believable." Treat any single productivity multiplier skeptically.
- **"BEAM stands for Bogdan's…" vs "Björn's…"** — both are correct depending on era. Mention both rather than picking one.
- **OTP's "Telecom" name is historical** — it is a general-purpose fault-tolerance framework now, not telecom-specific.
- **Soft real-time, not hard real-time.** Erlang is not for hard-deadline control loops; it's for predictable, low-jitter responsiveness at scale.

## Why it matters for the talk / what JVM folks can learn

**The framing for a JVM audience building modest-scale software:** the BEAM is not interesting because it powered a giant phone network — it's interesting because it bakes *operational resilience* into the runtime in a way the JVM leaves to libraries and discipline. Most of the audience won't hit hyperscale, but every one of them ships software that crashes, leaks, and needs upgrading without downtime.

Concrete contrasts and talking points:
- **Concurrency model.** BEAM processes are lightweight, isolated, scheduled by the VM (preemptive, per-process heaps, no shared mutable state). Compare to JVM threads (OS-backed, shared heap, locks). Even with Java's Project Loom virtual threads, the JVM does **not** give you per-process isolated heaps or "one crash doesn't corrupt the neighbor" by default. Erlang had this design in 1989.
- **"Let it crash" + supervision trees.** Instead of defensive try/catch everywhere, you isolate failure and let a supervisor restart a known-good state. This is a *philosophy*, not just a library — and it predates, and arguably inspired, a lot of modern resilience thinking (circuit breakers, the actor model in Akka, Kubernetes pod restarts as a coarse analogue).
- **Fault tolerance is in the runtime + OTP, not bolted on.** A JVM dev gets resilience from frameworks (Spring Retry, Resilience4j, Akka). On BEAM it's the default substrate. Quotable: *"On the JVM, fault tolerance is a library you remember to add. On the BEAM, it's the floor you stand on."*
- **Hot code upgrade.** BEAM could upgrade a running system in 1998. The JVM has class reloading hacks (JRebel, instrumentation) but nothing as principled.
- **The actor model lineage.** Akka explicitly borrowed Erlang/OTP ideas. Telling JVM devs "the thing Akka is modeling natively existed and shipped in production telecom gear decades ago" lands well.
- **Honesty sells.** Using the nine-nines myth *as a teaching moment about measuring reliability honestly* (Cronqvist's actual point: "debuggability is a property of a system") is more credible to an engineering audience than repeating marketing numbers.

Quotable one-liners:
- "Erlang was designed for phone switches in 1986, but the problem it solved — stay up, isolate failure, upgrade live — is everybody's problem now."
- "BEAM stands for Bogdan's, or Björn's, Erlang Abstract Machine — and that ambiguity is itself a nice reminder that this is 35+ years of accreted engineering, not a hype cycle."
- "The famous nine-nines number is half marketing and half truth — and the truth is the interesting half."

## Sources

- [Erlang (programming language) — Wikipedia](https://en.wikipedia.org/wiki/Erlang_(programming_language)) — creators, 1986 origin, Prolog/PLEX influence, name origin (Däcker, Agner Krarup Erlang), 1998 ban, Dec 1998 open-sourcing, Bluetail, Apache 2.0 license. Good for the high-level factual spine.
- [A Brief History of the BEAM Compiler — erlang.org blog](https://www.erlang.org/blog/beam-compiler-history/) — primary/official account of Prolog interpreter → JAM → TEAM → BEAM, the "40×/70× faster" figures, who wrote what, Björn Gustavsson, Core Erlang. Best source for the abstract-machine lineage.
- [The BEAM Book — Erik Stenman (blog.stenmans.org)](https://blog.stenmans.org/theBeamBook/) — authoritative on what BEAM stands for (Bogdan's / Björn's) and the BEAM-vs-ERTS distinction. Use for precise VM terminology.
- [A History of Erlang — Joe Armstrong, HOPL III (ACM)](https://dl.acm.org/doi/10.1145/1238844.1238850) — the canonical first-person history (telecom requirements, lab culture, the ban). Primary source; cite as the authoritative narrative even though full text is paywalled.
- [Making reliable distributed systems in the presence of software errors — Joe Armstrong PhD thesis, 2003 (erlang.org PDF)](https://erlang.org/download/armstrong_thesis_2003.pdf) — source of the verbatim AXD301 "11 node / 99.9999999% / how these figures were obtained was not documented" quote. Essential for the nine-nines nuance.
- [The nine nines — Mats Cronqvist, Erlang Factory SF Bay 2010 (PDF)](https://www.erlang-factory.com/upload/presentations/243/ErlangFactorySFBay2010-MatsCronqvist.pdf) — first-hand skeptic who worked on AXD301; the BT/marketing slide, "5 node-years," "Joe Armstrong was not part of the AXD 301 team," "the claim is pretty bogus," yet "amazingly reliable." The single best source for honest nine-nines framing.
- [All For Reliability: Reflections on the Erlang Thesis — DockYard](https://dockyard.com/blog/2018/07/18/all-for-reliability-reflections-on-the-erlang-thesis) — readable secondary that surfaces and contextualizes the thesis nine-nines quote. Good for slide-ready phrasing.
- [Open Telecom Platform — Wikipedia](https://en.wikipedia.org/wiki/Open_Telecom_Platform) — what OTP is (libraries + design principles + behaviours), supervision trees, the "branding" origin of the name. Good for the OTP section.
- [otp/.../design_principles.md — erlang/otp GitHub](https://github.com/erlang/otp/blob/master/system/doc/design_principles/design_principles.md) — primary docs on behaviours and supervision trees. Use to verify OTP specifics.
- [Industrial-Strength Functional Programming: Experiences with the Ericsson AXD301 Project — Blau & Rooth (ResearchGate)](https://www.researchgate.net/publication/238246524_Industrial-Strength_Functional_programming_Experiences_with_the_Ericsson_AXD301_Project) — the credible academic source on the AXD301's Erlang codebase size and team. Cite for LOC/team figures rather than blogs.
- [Gleam (programming language) — Wikipedia](https://en.wikipedia.org/wiki/Gleam_(programming_language)) — Louis Pilfold, 2016 start, v1.0 on 4 March 2024, static types, Erlang+JS targets, Rust toolchain, type-safe OTP. For the "languages today" + talk-headliner section.
- [gleam.run](https://gleam.run/) — official Gleam site; confirm current positioning/features.
- [Elixir (programming language) — Wikipedia](https://en.wikipedia.org/wiki/Elixir_(programming_language)) — José Valim, 2011–2012 origins, BEAM-hosted. For languages-today section.
- [LFE (programming language) — Wikipedia](https://en.wikipedia.org/wiki/LFE_(programming_language)) — Robert Virding, 2008, Lisp on Core Erlang/BEAM.
- [llaisdy/beam_languages — GitHub](https://github.com/llaisdy/beam_languages) — curated list of BEAM languages; good for the "and others" breadth.
- [AtomVM](https://atomvm.org/) — tiny BEAM-compatible VM for microcontrollers/WASM running Erlang/Elixir/Gleam. For the "BEAM beyond servers" angle.
- [Three Decades with Erlang — happihacking.com](https://happihacking.com/blog/posts/2023/erlang-history/) — readable secondary history corroborating JAM/TEAM/BEAM and the speed figures.
