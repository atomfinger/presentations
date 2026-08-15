# Concurrency on the BEAM

## TL;DR

The BEAM (Erlang's virtual machine, which also runs Gleam and Elixir) is built around
*processes* that are nothing like OS threads. A BEAM process is a green, VM-managed unit
of concurrency that starts at roughly **2.6 KB of memory** and is created/destroyed in
microseconds. Because each process owns a **private heap** and shares nothing, garbage
collection is **per-process** — there is no global, heap-wide stop-the-world pause that
freezes the whole runtime. Processes communicate only by **asynchronous message passing**
into per-process **mailboxes** (`send`/`receive`), so there are no locks and no data races
on shared mutable state. The scheduler is **preemptive via reduction counting**: every
process gets a fixed budget of "reductions" (~4000 today, 2000 before OTP 20) before it is
forcibly descheduled, which guarantees fairness and soft-real-time latency — one CPU-heavy
process cannot starve the rest. By default the BEAM runs **one scheduler thread per CPU
core**, each with its own run queue, using work-stealing and load migration to balance
work, plus **dirty schedulers** to isolate long-running native or CPU-bound work.

The headline demo: in **January 2012**, WhatsApp reported **over 2 million concurrent TCP
connections on a single FreeBSD/Erlang server** — a tuned benchmark, but a real one, and a
great illustration of what cheap processes make possible.

The JVM has historically mapped threads 1:1 onto OS threads (heavy, large stacks, limited
count). **Project Loom / virtual threads (JEP 444, Java 21, Sept 2023)** close a large part
of that gap by giving the JVM cheap, M:N-scheduled "virtual threads." This is a genuine
convergence toward BEAM-style lightweight concurrency — but meaningful differences remain
(shared heap and shared GC, cooperative scheduling with no time-slicing, pinning, and no
built-in per-process isolation, mailboxes, or supervision).

## Key facts & mechanics

### Processes are VM-level green processes, not OS threads
- A BEAM process is scheduled and managed entirely by the VM, not the operating system.
  It is **not** an OS thread and does not consume an OS thread or an OS-sized stack.
- Processes are extremely cheap to spawn and tear down, which is why idioms like
  "spawn a process per connection," "per request," or even "per task" are normal on the
  BEAM rather than exotic. Running hundreds of thousands to millions of processes on one
  node is a design point, not a stunt.

### Share-nothing + per-process heaps → per-process GC, no global pause
- Each process has **its own stack and heap, allocated in the same memory block, growing
  toward each other**; when they meet, GC for *that process* runs. (erlang.org GC docs.)
- GC is a **per-process generational semi-space copying collector** (Cheney's algorithm)
  with a global large-object space for big binaries. Because heaps are process-local and
  share nothing, **collecting one process does not stop the others** — there is no
  heap-wide, runtime-global stop-the-world pause. This is the sharpest contrast with the
  classic JVM model, where GC operates over a shared heap and (depending on collector)
  can introduce application-wide pause times.
- Consequence: GC latency is *small and localized*. A 2.6 KB process collects in trivial
  time; pauses scale with one process's live data, not the whole node's heap.

### The actor model: mailboxes, send/receive, no shared mutable state
- Processes do not share memory. They communicate by **asynchronous message passing**:
  one process `send`s a message, which is copied into the recipient's **mailbox**, and the
  recipient pulls messages with `receive` (with pattern matching and selective receive).
- Because messages are copied and state lives inside a single process, there is **no shared
  mutable state across processes** — hence **no locks, mutexes, or data races** in ordinary
  application code. Concurrency bugs become sequencing/protocol bugs inside a process rather
  than memory-corruption races.
- In Gleam specifically, this actor model is exposed through OTP-style abstractions
  (e.g. `gleam_otp` actors) layered on the same BEAM primitives.

### Preemptive scheduling via reduction counting
- The BEAM is **preemptive**, but it achieves preemption through **reduction counting**
  rather than OS timer interrupts. A *reduction* is roughly "a unit of work" — historically
  one function call is counted as one reduction (other operations also cost reductions).
- Each process is given a budget of reductions when scheduled. When it exhausts the budget,
  it is **descheduled at a safe point** and the next runnable process is given the CPU. The
  Beam Book describes this as **"preemptive scheduling on top of cooperative scheduling"**:
  the VM inserts the yield checks, so application code never has to cooperate explicitly.
- This is what gives the BEAM **fairness and soft-real-time behavior**: a process doing a
  long computation gets sliced after its reduction budget and cannot monopolize a scheduler
  or starve other processes. (Caveat: a single uninterruptible native call can break this —
  see dirty schedulers below.)

### One scheduler per core, run queues, work stealing, dirty schedulers
- By default the BEAM starts **one scheduler thread per available CPU core** (physical or
  hyperthread) on SMP systems. Each scheduler has its own set of **run queues**.
- Run queues are **priority-aware** (max / high / and a combined normal+low queue), with a
  starvation-avoidance mechanism so low-priority work still eventually runs.
- The runtime **balances load** across schedulers: an idle scheduler will **steal work**
  from a busy one, and a *migration* strategy tries to both compact load (so cores can
  sleep when idle) and spread it (so no scheduler is overloaded).
- **Dirty schedulers** handle work that would otherwise break the reduction model: a NIF
  (native C function) or operation that cannot yield in ~1 ms is classified as a **dirty
  NIF** and runs on a separate pool of **dirty CPU** or **dirty I/O** schedulers, so it does
  not block a normal scheduler or stall the run queue. (Note: a process running a dirty NIF
  cannot be GC'd or suspended until the NIF returns.)

### Contrast with the JVM
- **Platform threads** are mapped **1:1 to OS threads**: relatively heavy, with large
  reserved stacks (commonly on the order of ~512 KB–1 MB, configurable via `-Xss` /
  `-XX:ThreadStackSize`, platform-dependent), scheduled by the OS, and practically limited
  to thousands rather than millions.
- **Virtual threads (Project Loom, JEP 444, Java 21)** are lightweight, JDK-scheduled
  threads multiplexed (M:N) onto a small pool of **carrier** platform threads via a
  work-stealing **`ForkJoinPool` in FIFO mode** (default parallelism = available
  processors). A virtual thread **unmounts** from its carrier when it blocks (typically on
  I/O), freeing the carrier for another virtual thread. Oracle's own docs say you can "have
  a great many active virtual threads, even millions, running in the same Java process."
  This is a real, large step toward BEAM-style concurrency.
- Remaining differences (fair version):
  - **Scheduling model:** Virtual threads are scheduled around blocking points and the JDK
    scheduler **does not implement time-sharing / preemption of CPU-bound code** — a virtual
    thread that runs a tight CPU loop without blocking will not be sliced off its carrier
    the way a BEAM process is sliced after its reduction budget.
  - **Pinning:** A virtual thread is **pinned** to its carrier (cannot unmount) while inside
    a `synchronized` block/method or while running a `native`/foreign-function call. Heavy
    pinning can exhaust carriers. (JDK 24's JEP 491 removed most `synchronized`-related
    pinning, narrowing this gap further.)
  - **Memory model:** Virtual threads share **one heap and one GC**. There is no per-thread
    private heap, so the BEAM's "GC one process at a time, no global pause" property does not
    transfer; the JVM still relies on its (now low-pause) collectors like G1/ZGC.
  - **Isolation & primitives:** The JVM has **no built-in per-process isolation, no
    language-level mailbox/`receive`, and no built-in supervision** equivalent to OTP. Loom
    gives you cheap threads; it does not give you the actor model, message-passing isolation,
    or "let it crash" supervision out of the box.

## Numbers & benchmarks

| Fact | Value | Source |
|---|---|---|
| Total memory of a freshly spawned process | **327 words = 2,616 bytes** on 64-bit | erlang.org Efficiency Guide, "Processes" |
| Of which, initial heap area (incl. stack) | **233 words** | erlang.org Efficiency Guide, "Processes" |
| Heap growth | starts at 233 words, grows ~Fibonacci, then ~20% steps above ~1 Mword | erlang.org Efficiency Guide / Beam Book |
| Default max simultaneous processes | **1,048,576** (2^20) | erlang.org "System Limits" |
| Max via `+P` startup flag | up to **268,435,456** (2^28); unreachable on 32-bit due to memory | erlang.org "System Limits" |
| Reduction budget per scheduling slice (`CONTEXT_REDS`) | **4000** today; **2000** before OTP-20.0 | The Beam Book, scheduling chapter |
| I/O poll interval (`INPUT_REDUCTIONS`) | `2 * CONTEXT_REDS` (~8000 reductions) | The Beam Book, scheduling chapter |
| Scheduler threads | **one per available CPU core** (SMP) by default | The Beam Book, scheduling chapter |
| WhatsApp single-server connections | **>2,000,000 TCP connections** | WhatsApp blog, "1 million is so 2011," 6 Jan 2012 |

**Process memory, precisely:** The Erlang/OTP Efficiency Guide ("Processes") states that a
newly spawned process uses **327 words of memory**, of which **233 words is the heap area
(including the stack)**, and that on a 64-bit system this small process measured **2,616
bytes**. The guide notes the conservative 233-word initial heap "is quite conservative to
support Erlang systems with hundreds of thousands or even millions of processes." So the
commonly cited "~2–3 KB / ~300+ words" figure is accurate; the exact total is 327 words /
2,616 bytes on 64-bit. (On 32-bit systems word size is 4 bytes, so byte counts are smaller.)

**Reductions, precisely:** The Beam Book's scheduling chapter states the current
`CONTEXT_REDS` is **4000** and explicitly notes "Prior to OTP-20.0, the value of
`CONTEXT_REDS` was 2000." So the widely repeated "~2000 reductions" figure is correct for
older systems but **out of date** for modern OTP — use ~4000 (and "~2000 historically") to
be accurate. A function call counts as a reduction; the scheduler also checks for I/O after
roughly `2 * CONTEXT_REDS` reductions.

**WhatsApp 2M (the hook):** On **6 January 2012**, the WhatsApp engineering blog post
titled **"1 million is so 2011"** reported pushing a single server to **over 2 million TCP
connections**, after previously hitting 1 million. The machine ran **FreeBSD 8.2-STABLE
(amd64)** on an Intel Xeon X5675 (24 cores @ 3.07 GHz) with ~103 GB RAM, and they reported
doing it "with plenty of CPU and memory to spare" (the posted snapshot showed ~38% CPU and
tens of GB of free RAM). Honest framing for the talk: this was a **deliberately tuned
benchmark** (kernel/socket tuning, a purpose-built Erlang server, idle-ish connections), not
a claim that any Erlang app gets 2M busy users per box for free. It's a powerful, *real*
demonstration of what cheap processes + per-connection processes enable.

## Nuance & caveats

- **"Millions of processes" has real requirements.** Cheap ≠ free. A million *idle*
  processes at ~2.6 KB each is already on the order of a couple of GB of process overhead
  before any application state, mailbox backlog, or binaries. You also need to raise the
  `+P` limit if you exceed the 1,048,576 default, give the node enough RAM, and watch for
  mailbox growth (an overwhelmed process whose mailbox grows unboundedly is a classic BEAM
  failure mode). The WhatsApp number worked because connections were lightweight and the
  system was tuned end-to-end. Treat "millions of processes" as "the architecture permits
  it," not "it's automatic."
- **The BEAM is not built for raw CPU-bound number crunching.** Its strengths are massive
  concurrency, low and predictable latency, fault isolation, and I/O-bound / messaging
  workloads. For tight numeric inner loops, the BEAM is generally **slower** than the JVM
  (JIT-compiled, optimized for throughput) or native code. The idiomatic answer is to push
  heavy CPU work into **NIFs / dirty schedulers** or external services — which also means
  giving up some of the soft-real-time guarantees for that work. If your problem is "make
  one CPU core go as fast as possible," the JVM is often the better tool; if it's "handle
  huge numbers of concurrent, mostly-I/O activities with steady tail latency," the BEAM
  shines.
- **Loom is genuinely closing gaps — say so.** Virtual threads make "a thread per request /
  per task" affordable on the JVM and remove a lot of the historical thread-count ceiling.
  JEP 491 (JDK 24) further reduced pinning. A fair talk acknowledges that the *cheap
  lightweight unit of concurrency* gap has narrowed a lot. The durable BEAM advantages are
  less about "cheap threads" and more about the **whole model**: per-process heaps and
  independent GC (no shared-heap pause coupling), preemptive reduction-based fairness even
  for CPU-bound code, and the built-in actor/mailbox + OTP supervision story. Those are
  architectural, not just performance, properties.
- **Preemption has one escape hatch.** A long-running, non-yielding **NIF** that is *not*
  marked dirty can block a scheduler and undermine the fairness guarantee — which is exactly
  why dirty schedulers exist. The soft-real-time property holds for ordinary BEAM code, not
  for arbitrary native code.

## Why it matters for the talk / what JVM folks can learn

- **Concurrency as a first-class, cheap default.** On the BEAM you don't pool or ration the
  unit of concurrency — you spawn a process per connection/request/task and let the
  scheduler sort it out. JVM developers now have the analogous tool in virtual threads;
  the lesson is the *mental model shift* from "threads are scarce, pool them" to "the
  lightweight concurrency unit is cheap, use one per logical task."
- **Isolation by default removes a whole bug class.** Share-nothing + message passing means
  no locks and no data races in normal code. That's a different and arguably more robust
  default than "shared memory + careful synchronization." Even with Loom, the JVM keeps the
  shared-heap model, so this remains a BEAM teaching point.
- **Gleam types the messages the BEAM leaves untyped.** A raw BEAM mailbox accepts *any* term,
  so a wrong message is a runtime surprise. Gleam wraps process communication in typed channels
  (a `Subject(message)` from `gleam_erlang`/`gleam_otp`): a process declares exactly which
  messages it accepts and the compiler enforces it. You keep the actor model's ergonomics and
  lose the "what's actually in this mailbox?" guesswork — a concrete illustration of the talk's
  thesis that Gleam brings static typing to this ecosystem.
- **GC latency is a design property, not a tuning afterthought.** Per-process heaps mean GC
  pauses are tiny and local by construction — no node-wide stop-the-world coupling. JVM folks
  spend real effort tuning collectors (G1/ZGC/Shenandoah) to chase low pause times; the BEAM
  gets a lot of that "for free" from its memory architecture (at the cost of raw throughput).
- **Fairness for CPU work, not just I/O.** Reduction-based preemption slices *any* process,
  including CPU-bound ones, so tail latency stays predictable under mixed load. Loom's
  scheduler, by contrast, leans on blocking points and does not time-slice CPU-bound virtual
  threads — a concrete, honest difference to highlight.
- **The hook lands because it's about the model, not magic.** WhatsApp's 2M connections is
  memorable precisely because cheap per-connection processes + per-process GC + preemptive
  fairness make "a process per connection" a sane architecture. Use it as the opener, then
  explain *why* it's possible.

## Sources

> Accuracy note: only sources actually retrieved during research are listed. The official
> OpenJDK JEP 444 page (`https://openjdk.org/jeps/444`) returned HTTP 403 on direct fetch;
> its scheduler/pinning details below are corroborated via Oracle's official Java 21
> "Virtual Threads" guide (fetched) and search excerpts quoting JEP 444. See unverified-claims
> note at the end.

- **Erlang/OTP Efficiency Guide — "Processes"** —
  https://www.erlang.org/doc/system/eff_guide_processes.html — *Primary source.* Gives the
  327-words / 2,616-bytes (64-bit) figure for a newly spawned process, the 233-word initial
  heap (incl. stack), heap-growth behavior, and the rationale that the conservative initial
  heap supports "hundreds of thousands or even millions of processes."
- **Erlang/OTP "System Limits"** —
  https://www.erlang.org/doc/system/system_limits.html — *Primary source.* Default maximum
  of 1,048,576 simultaneous processes, raisable via `+P` up to 268,435,456, with the 32-bit
  memory caveat.
- **Erlang/OTP ERTS "Erlang Garbage Collector"** —
  https://www.erlang.org/doc/apps/erts/garbagecollection.html — *Primary source.* Per-process
  heap+stack in one block growing toward each other; per-process generational semi-space
  copying collector (Cheney's algorithm) + global large-object space.
- **The Beam Book — Scheduling chapter** —
  https://github.com/happi/theBeamBook/blob/master/chapters/scheduling.asciidoc — *Primary /
  authoritative community reference.* `CONTEXT_REDS` = 4000 today (2000 before OTP-20.0),
  `INPUT_REDUCTIONS` = `2*CONTEXT_REDS`, "preemptive scheduling on top of cooperative
  scheduling," one scheduler thread per enabled core, priority run queues, work stealing and
  migration, low-priority starvation avoidance.
- **Erlang/OTP ERTS `erl_nif` docs** —
  https://www.erlang.org/doc/apps/erts/erl_nif.html — *Primary source.* Definition of dirty
  NIFs (work that can't finish in ~1 ms), dirty CPU vs dirty I/O scheduler classification,
  and the caveat that a process running a dirty NIF can't be suspended/GC'd until it returns.
- **WhatsApp Blog — "1 million is so 2011"** —
  https://blog.whatsapp.com/1-million-is-so-2011 — *Primary source for the hook.* 6 Jan 2012;
  >2 million TCP connections on one FreeBSD 8.2-STABLE server (Intel Xeon X5675, ~103 GB RAM),
  "with plenty of CPU and memory to spare." A tuned benchmark.
- **Oracle — "Virtual Threads" (Java SE 21 Core Libraries guide)** —
  https://docs.oracle.com/en/java/javase/21/core/virtual-threads.html — *Primary source for
  Loom.* Virtual threads are JDK-implemented and mounted on carrier platform threads;
  unmount on blocking I/O; pinning occurs inside `synchronized` blocks/methods and `native`/
  foreign-function calls; "we can easily have a great many active virtual threads, even
  millions"; "not faster threads … exist to provide scale (higher throughput), not speed."
- **JEP 444: Virtual Threads (OpenJDK)** —
  https://openjdk.org/jeps/444 — *Primary spec (fetched 403; details via search excerpts and
  the Oracle guide).* Scheduler is a work-stealing `ForkJoinPool` in FIFO mode; default
  parallelism = number of available processors (tunable via
  `jdk.virtualThreadScheduler.parallelism`); scheduler may temporarily exceed parallelism to
  compensate for captured carriers; delivered final in Java 21.
- **JEP 491: Synchronize Virtual Threads without Pinning (OpenJDK)** —
  https://openjdk.org/jeps/491 — Referenced for the claim that JDK 24 removed most
  `synchronized`-related pinning (gap-narrowing caveat).
- **OpenJDK — JDK 21 project page** —
  https://openjdk.org/projects/jdk/21/ — Java 21 reached General Availability on
  **19 September 2023** (LTS).
- **Baeldung — "Configuring Stack Sizes in the JVM"** —
  https://www.baeldung.com/jvm-configure-stack-sizes — *Secondary.* Context for default
  platform-thread stack sizes (~512 KB–1 MB, platform-dependent) and `-Xss` /
  `-XX:ThreadStackSize`. (Fetch returned 403; figure is well-known and cross-referenced, but
  treat the exact default as platform-dependent — see unverified claims.)

### Unverified / flagged claims

- **JEP 444 exact wording** ("does not implement time sharing," exact pinning list, FIFO
  ForkJoinPool, default parallelism): the canonical JEP page returned **HTTP 403** to the
  fetch tool. The scheduling-model and pinning facts are corroborated by Oracle's fetched
  Java 21 guide and by search excerpts quoting JEP 444 verbatim, but I did not retrieve the
  JEP page body directly. Verify against https://openjdk.org/jeps/444 before quoting it
  word-for-word on a slide.
- **Default JVM platform-thread stack size (~512 KB–1 MB):** the Baeldung page returned 403
  on fetch. This range is well-established and platform/version-dependent (HotSpot defaults
  differ across Linux/Windows/macOS and architectures). Do **not** present a single universal
  number; say "commonly ~512 KB–1 MB, platform-dependent, configurable via `-Xss`."
- **WhatsApp benchmark being "tuned/idle connections":** the blog post itself emphasizes
  spare CPU/RAM; the characterization that these were lightweight/idle benchmark connections
  (rather than fully active users) is the widely accepted reading and consistent with the
  hardware/CPU figures, but the post does not exhaustively describe the connection workload.
  Present it as a tuned benchmark (accurate) rather than overstating it.
