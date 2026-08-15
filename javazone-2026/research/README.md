# Research: BEAM for *"Gleam and BEAM: Looking beyond the JVM"* (JavaZone 2026)

Reference material for the 45-minute JavaZone 2026 talk. The audience is mostly **JVM/Java developers**, most of whom build **modest-scale** software. The job of these documents is to give accurate, well-sourced ammunition for two messages:

1. **Why the BEAM can be great** — and
2. **What JVM developers can learn from it**, even if they never touch Erlang/Elixir/Gleam.

This round is **BEAM-focused** (Gleam-specific research is a separate, later round — see *Scope* below).

## How to use this

Each document is a self-contained **deep-reference** dossier with the same shape:

- **TL;DR** → the one-paragraph version
- **Key facts & mechanics** → how it actually works (not just slogans)
- **Numbers & benchmarks** → only figures with a real, cited source
- **Nuance & caveats** → where the popular story is wrong or oversold
- **Why it matters for the talk / what JVM folks can learn** → the angle + quotable lines
- **Sources** → annotated links, marked *fetched directly* vs *via search result*

Mine the **"Why it matters"** and **"Numbers"** sections first when building slides; lean on **"Nuance & caveats"** to keep the talk honest in front of a skeptical audience.

## The documents

| # | Document | What it covers |
|---|----------|----------------|
| 01 | [History & origins](01-history-erlang-beam.md) | Ericsson roots (Armstrong/Virding/Williams, ~1986), the telecom problem, Erlang→OTP→BEAM, open-sourcing, AXD301, today's BEAM languages |
| 02 | [Fault tolerance](02-fault-tolerance.md) | "Let it crash", process isolation, links vs monitors, `gen_server`/supervisors, restart strategies — vs JVM try/catch |
| 03 | [Concurrency](03-concurrency.md) | Lightweight processes (~2.6 KB each), per-process GC (no stop-the-world), mailboxes, reduction-based preemption, schedulers — vs JVM threads & **Loom** |
| 04 | [Distribution](04-distribution.md) | "Distributed by default": nodes, `epmd`, location transparency, `global`/`pg`/`mnesia` — and the honest caveats (split-brain, security, mesh limits) |
| 05 | [Hot code swapping](05-hot-code-swapping.md) | Two module versions, `code_change/3`, releases/appups/relups — a real capability, but why most shops now use blue-green/rolling deploys |
| 06 | [BEAM vs JVM](06-beam-vs-jvm.md) | Fair side-by-side table, **where the JVM genuinely wins**, where the BEAM wins, and how Loom/Akka show the JVM converging on BEAM ideas |
| **07** | [**Why the BEAM, even without hyperscale**](07-why-beam-without-hyperscale.md) | **The persuasive core.** Why pick the BEAM at *ordinary* scale, where Java is the default: reliability, predictable latency, simple concurrency, fewer moving parts, live introspection, productivity — plus honest "when NOT to" |

**Read 07 last and weight it heaviest.** Docs 01–06 map onto the talk's BEAM outline; **07 answers the question that actually persuades this audience** — *"why would I reach for the BEAM when I'm not Google and Java already works?"*

## Framing & accuracy notes

- **Scale stories are hooks, not the argument.** "Millions of processes" (doc 03) and WhatsApp's "2 million connections on one server" (doc 03) are kept as attention-grabbers — cited and contextualized — but the *case for adoption* lives in doc 07, because most of the room isn't operating at that scale.
- **Guardrails on the over-repeated claims:** the AXD301 **"nine nines" (99.9999999%)** figure (doc 01) and **"distributed by default"** (doc 04) are presented with their real nuance, not as flat facts, so nothing on stage falls apart under a sharp question.
- **Fair to the JVM:** doc 06 explicitly lists where the JVM wins (raw throughput, JIT, ecosystem, ZGC/Shenandoah low-pause GC) — the talk lands better by conceding these.
- **Examples are given in Gleam, not Elixir.** BEAM *mechanics* are language-agnostic, but wherever a doc reaches for a concrete library, it names the **Gleam-native, typed** option first — `gleam_otp` (actors/supervisors), Lustre (real-time UI), Wisp + Mist (web), `glyn` (pub/sub), `pog` (Postgres) — see docs 02, 03, 04, 07. The honest unifier: Gleam compiles to Erlang and can call any Erlang/Elixir/Hex package via FFI (`glixir` for typed OTP interop), so where Gleam's own library is young, the mature Elixir/Erlang one (Phoenix.PubSub, Oban, …) is still reachable. Gleam's distinctive angle — **static typing over OTP** (typed messages/`Subject`, typed supervision) — is flagged in docs 02 and 03 as a talk headline.
- **Verify-before-stage flags:** a handful of claims are marked *"via search result"* or *"flagged"* in each doc's Sources / caveats — double-check those specific figures before putting them on a slide. All cited URLs were link-checked and resolve (a few primary sources like openjdk.org and ACM block automated fetches but are live in a browser).

## Scope

- **In scope (this round):** the BEAM VM and its ecosystem — the six pillars above plus the modest-scale case. Ecosystem examples are named in **Gleam** terms (with Elixir/Erlang interop noted) so the material fits a Gleam talk.
- **Out of scope (possible follow-up):** a dedicated deep-dive on Gleam *itself* — its type system, syntax, build tooling/package management, and a worked full-stack Gleam demo. These docs reference Gleam libraries where a BEAM point needs an example, but they don't yet teach Gleam end-to-end. Same template applies when that round happens.
- **Not produced here:** slides and `script.md` — this directory is research only.
