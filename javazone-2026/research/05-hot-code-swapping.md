# Hot Code Swapping on the BEAM

## TL;DR

The BEAM (the Erlang virtual machine) can load a new version of a module into a *running* system without stopping it — and without dropping the work in flight. The mechanism is simple at its core: the code server keeps **two versions of each module loaded at once** — "current" and "old" — and processes already executing the old code keep running it until they make a *fully-qualified* call (`Module:function(...)`), at which point they jump to the new version. Long-lived stateful processes (`gen_server`s) survive a version change via the `code_change/3` callback, which migrates their internal state. For full production upgrades, OTP layers a whole machinery on top — `.app`/`.appup`/`.relup` files and the `release_handler` — that can upgrade an entire running release with state migration and even automatic rollback.

This capability is genuinely impressive and was born of a real need: telecom switches like Ericsson's AXD301 had to be patched and upgraded *in service*, with uptime measured in years and no dropped calls. But be honest with a JVM audience: doing this **safely for non-trivial state changes is hard and error-prone**, and **most modern Erlang/Elixir shops do not use it for routine deploys.** Elixir's own release tooling does not support hot upgrades out of the box and explicitly steers teams toward blue-green / rolling / canary deploys. Hot code loading still shines in specific places: embedded/telecom, the interactive REPL and `recon` debugging workflow, hot-patching a single fix into a live node, and stateful systems where dropping connections is genuinely unacceptable.

The JVM has analogous tech (JVMTI `RedefineClasses`, JRebel, DCEVM/HotswapAgent), but it is mostly a *development-time* convenience limited to swapping method bodies — not a first-class, production, no-downtime, state-migrating upgrade story like BEAM relups.

## Key facts & mechanics

### Two versions: "current" and "old"

From the Erlang docs on compilation and code loading: "The code of a module can exist in two variants in a system: *current* and *old*." When a module is first loaded it becomes *current*; load it again and "the code of the previous instance becomes 'old' and the new instance becomes 'current'." Crucially, "Both old and current code are valid, and can be evaluated concurrently." (erlang.org, *Compilation and Code Loading*.)

This is the whole trick. The VM doesn't mutate running code in place — it keeps two generations side by side and lets processes migrate between them lazily.

### Fully-qualified calls jump; local calls stay put

The rule that makes this safe: "Fully qualified function calls always refer to current code. Old code can still be evaluated because of processes lingering in the old code." (erlang.org, *Compilation and Code Loading*.)

In practice, a long-running loop is written so that each iteration calls itself with a fully-qualified call — `?MODULE:loop(State)` rather than a bare `loop(State)`. A bare *local* call stays inside whatever version the process is already running; the *fully-qualified* call is the deliberate "checkpoint" where the process picks up the newest version. This is why you often see `?MODULE:` qualifiers in hand-written server loops — they are upgrade points.

### The third load purges the oldest version (and kills lingering processes)

There is no "version 3 alongside 1 and 2." If you load a module a third time while processes still linger in the old code: "the code server removes (purges) the old code and any processes lingering in it are terminated. Then the third instance becomes 'current' and the previously current code becomes 'old'." (erlang.org, *Compilation and Code Loading*.) So a process that never reaches a fully-qualified call before two reloads happen gets killed when its version is purged.

### The functions

From the `code` module reference (erlang.org, *kernel: code*):

- **`code:load_file(Module)`** — "Tries to load the Erlang module `Module` using the code path." This is the loader; loading a module that's already current pushes the existing copy to "old."
- **`code:purge(Module)`** — "Purges the code for `Module`, that is, removes code marked as old. If some processes still linger in the old code, these processes are killed before the code is removed." (The aggressive option.)
- **`code:soft_purge(Module)`** — "Purges the code for `Module` ... but only if no processes linger in it." Returns `false` (and does nothing) if any process is still in the old code; otherwise removes it and returns `true`. (The safe option — never kills a process.)
- **`code:load_binary/3`** — loads object code from a binary, and "can be used to load object code on remote Erlang nodes" — the basis for pushing a patched module to another node over distribution.

A common pattern when reloading repeatedly is the classic "purge twice" idiom: purge the old version *before* loading the new one, because the system can only hold two versions and a fresh load would otherwise auto-purge (and kill) whatever was still in the oldest copy.

### Surviving a version change: `gen_server` and `code_change/3`

A bare `spawn`ed loop is fragile across upgrades, because the process is literally executing the module being swapped. The idiomatic answer is OTP behaviours. As the AppSignal guide puts it, with a `GenServer` "our pid process doesn't spin in [our] code. It runs a GenServer loop" — the process lives inside the (stable) `gen_server` library code and only *calls out* to your callback module, so swapping your callbacks is safe.

When your *state shape* changes between versions, you need to migrate it. That's `code_change/3` (erlang.org, *stdlib: gen_server*):

```
code_change(OldVsn, State, Extra) -> {ok, NewState} | {error, Reason}
```

- It "is called by a gen_server process when it is to update its internal state during a release upgrade/downgrade," i.e. when the `.appup` file specifies an `{update, Module, ...}` instruction.
- For an upgrade `OldVsn` is the old module version; for a downgrade it's `{down, Vsn}`. `Extra` is passed straight through from the `{advanced, Extra}` part of the upgrade instruction.
- If it returns `{error, Reason}`, "the ongoing upgrade will fail and roll back to the old release."

Under the hood the `sys` module orchestrates this for any OTP behaviour: `sys:suspend/1` the process, `sys:change_code/4` (which triggers `code_change/3`, or `system_code_change/4` for the generic `sys`/`proc_lib` machinery behind custom behaviours), then `sys:resume/1`.

### The "proper" production way: OTP releases, appup, relup, release_handler

Loading one module by hand is fine for a quick patch. Upgrading a whole running *system* coherently — multiple applications, dependency ordering, state migration, rollback — is what OTP's release machinery is for. The pieces (erlang.org, *Release Handling*; *Appup Cookbook*):

- **`.app` file** — per-application metadata: modules, version (`vsn`), dependencies.
- **`.rel` file** — describes a whole release: which applications and versions make it up. The boot script is generated from it.
- **`.appup` file** — the *application upgrade* recipe: how to go from one application version to another, as a list of instructions. Shape (from Learn You Some Erlang):
  ```
  {NewVersion,
   [{VersionUpgradingFrom, [Instructions]}],
   [{VersionDowngradingTo, [Instructions]}]}.
  ```
  Instructions include high-level ones like `{load_module, Mod}`, `{update, Mod, {advanced, Extra}}` (triggers `code_change/3`), and `{apply, {M, F, A}}`.
- **`.relup` file** — the *release upgrade* script: low-level, ordered instructions to move the entire release from one version to another. "All versions of a release, except the first one, must contain a `relup` file." It is generated by `systools:make_relup/3,4`, which reads the `.rel`, `.app`, and `.appup` files and works out the correct application add/remove/upgrade/downgrade ordering, expanding high-level appup instructions into low-level ones.
- **`release_handler`** — a SASL process that "handles unpacking, installation, and removal of release packages." You call it on each node to unpack, install, make permanent (or roll back) a release. It drives the suspend → `code_change` → purge → resume dance described above.

In Elixir-land, this used to be provided by **Distillery** (and its `relups`); modern Elixir uses the built-in `mix release`, which deliberately does *not* generate appups/relups (see caveats).

### Why it exists: telecom uptime measured in years

Erlang was built at Ericsson for telephone switches that must never stop. The design requirement was explicit: because the system runs non-stop, "it must be possible to change the software without disturbing traffic in the system" (the AXD301's stated requirements, per DockYard's reflection on the Erlang thesis). You patch a bug or roll out a feature while calls are in progress — no maintenance window, no dropped calls. Hot code loading is the language-level feature that makes in-service upgrades possible; the AXD301 ATM switch (~2 million lines of Erlang) is the canonical example. (See the *Numbers* section on the famous "nine nines" claim and the caveats around it.)

## Numbers & benchmarks

This topic is mostly qualitative; the headline numbers are reliability/uptime claims, and they deserve care.

- **The "nine nines" (99.9999999%) claim.** The most-cited figure is that Ericsson's AXD301 achieved 99.9999999% uptime — roughly **32 milliseconds of downtime per year**. Joe Armstrong popularized it, and it's a great story, but **treat it as folklore, not a measured benchmark.** Even Armstrong's own thesis is cautious: per DockYard's summary, "The only information on the long-term stability of the system came from a PowerPoint presentation showing some figures claiming that a major customer had run an 11 node system with a 99.9999999% reliability, though how these figure had been obtained was not documented." The claim "has been the subject of some debate" and is "uncertain." For a talk: present it as a famous, motivating anecdote and flag the sourcing, rather than asserting it as a verified metric.
- **AXD301 scale.** Frequently cited as ~2 million lines of Erlang, an ATM switch handling traffic at high throughput (figures of up to ~160 Gbit/s appear in secondary sources). [Unverified against a primary Ericsson source — secondary/community figures only.]
- **Two-version limit.** A hard, verifiable VM fact, not a benchmark: the code server holds **exactly two** generations of a module (current + old); a third load purges the oldest. (erlang.org, *Compilation and Code Loading*.)
- **Testing overhead of relups.** Not a number but a telling qualitative datapoint: per Learn You Some Erlang, "divisions of Ericsson that do use relups spend as much time testing them as they do testing their applications themselves." That ~1:1 test ratio is the practical cost of doing hot upgrades safely.

## Nuance & caveats

This is the part to land honestly with a JVM crowd.

### It is genuinely complex and error-prone

Hot upgrades are not free magic; they are one of the hardest corners of OTP. Learn You Some Erlang is blunt: relups are "one of the most complex parts of OTP, difficult to comprehend and get right, on top of being time consuming," and recommends: "if you can avoid the whole procedure ... and do simple rolling upgrades by restarting VMs and booting new applications, I would recommend you do so. Relups should be one of these 'do or die' tools."

The Erlang release-handling docs themselves note "Many aspects can make release handling complicated" — inter-node and inter-process dependencies, module load ordering, and a timing window where freshly spawned processes may briefly run old code during the upgrade. And anything beyond a trivial code-only change forces you to hand-write `code_change/3` *and* the appup instructions correctly, with downgrade paths, for every changed application.

### Most modern shops don't use it for routine deploys

This is the key reality check. **Elixir releases do not support hot code upgrades out of the box.** The official `mix release` docs state plainly: "this feature is not supported out of the box by Elixir releases" because "they are very complicated to perform in practice, as they require careful coding of your processes and applications as well as extensive testing." They explicitly point teams to language-agnostic strategies instead: **blue/green, canary, and rolling deployments.** (mix.hexdocs.pm, *mix release*.)

This isn't only Elixir's official line; it's practitioner consensus. Cogini's "Best practices for deploying Elixir apps" files hot code updates under "Things you probably don't need right now" ("While they are cool, you don't initially need to worry about: Hot code updates") and recommends deploying whole releases that restart as a unit (e.g. via systemd). The Phoenix "Deploying with Releases" guide follows the same release-and-restart model.

The reason rolling restarts are cheap on the BEAM, ironically, is the same set of properties that make the platform great: **fast VM startup, supervision trees that bring a node back to a known-good state, and per-request process isolation** mean cycling nodes one at a time behind a load balancer is simple and reliable. When the orchestration layer (Kubernetes, etc.) already gives you zero-downtime rolling deploys for free, the cost/benefit of maintaining appup/relup recipes for every release rarely pays off.

### Where it still genuinely shines

Be fair — it's not a museum piece:

- **Embedded / telecom / appliances** where there's no orchestrator, no spare node, and you truly cannot drop the session — the original use case (Nerves devices in the field, switches, long-lived gateways).
- **The interactive workflow.** In the REPL/`iex` you reload a module and keep your session — this is everyday developer ergonomics, not a production upgrade.
- **Emergency hot-patching a live node.** Push a fixed module to a running production node to stop the bleeding *now*, without a full deploy. Fred Hébert's `recon` library supports exactly this with `recon:remote_load/1`, which takes a local module and loads it onto a remote node in a diskless manner. This is a debugging/firefighting tool, used deliberately and sparingly.
- **Truly stateful, can't-drop-connections systems** (large persistent connection pools, in-memory game/session state, trading systems) where bouncing a node means a visible, costly disruption — here the investment in proper relups can be worth it.

A clean framing for the talk: **hot code loading is a capability, not a default.** The BEAM makes the *impossible* (in-service state-migrating upgrades) *possible*; orchestration makes the *common case* (zero-downtime deploys) *easy*, so most teams reach for the easy thing.

### Contrast with the JVM

The JVM has real hot-reload tech, but the ceiling is much lower and the use case is different:

- **JVMTI `RedefineClasses` (HotSwap).** Built into the platform and used by debuggers ("fix-and-continue"). The restrictions are strict: per Oracle's JVMTI spec the redefinition "must not add, remove or rename fields or methods, change method signatures, or change inheritance" — effectively **method bodies only.** Its stated intent is "instrumentation ... and, during development, for fix-and-continue debugging" — i.e. explicitly a dev-time mechanism. In practice even a method-body change can be defeated by the compiler emitting synthetic members.
- **DCEVM + HotswapAgent.** A patched HotSpot VM that lifts those limits (add/remove/modify fields, methods, annotations). Powerful, but it's a non-standard VM and squarely aimed at the dev inner loop, not production rollouts.
- **JRebel.** A commercial agent using the Instrumentation API + classloader tricks to give richer reload without a special VM. Again, primarily a developer productivity tool to avoid redeploys.

The decisive differences: none of these migrate **process/object state across an incompatible change** (there is no JVM equivalent of `code_change/3` driving a coordinated, rollback-capable state transformation), and none is positioned as a first-class **production** no-downtime upgrade story. On the JVM, the production answer to zero-downtime is the same one most BEAM shops now use anyway — rolling/blue-green deploys behind a load balancer. The honest takeaway: the BEAM's hot-reload is *deeper* (state-aware, production-grade, language-integrated) where the JVM's is *shallower* (mostly method bodies, mostly dev-time) — but in everyday practice both ecosystems converge on rolling deploys.

## Why it matters for the talk / what JVM folks can learn

- **The "two versions side by side" model is the elegant idea worth showing.** It's a tiny, comprehensible mechanism (current + old, fully-qualified calls migrate forward, third load purges) that yields something the JVM can't really do. Even if nobody in the room ever ships a relup, the *design* — lazy, per-process migration instead of in-place mutation — is a genuinely instructive piece of systems thinking.
- **State migration is a first-class concern.** `code_change/3` exists because the runtime takes seriously that *running processes hold state* and upgrading code means evolving that state. JVM hot-reload simply doesn't model this. Even for teams doing rolling deploys, the discipline of "how does in-flight state survive a version change?" is a transferable lesson (it shows up in DB migrations, schema evolution, rolling-deploy compatibility windows).
- **Capability vs. practice — and that's OK.** The most honest and credible point: the BEAM *can* do in-service upgrades, and that capability shaped the whole platform (supervision, isolation, fast restart). But the community itself mostly chose the simpler path of rolling restarts, *because the platform makes restarts cheap.* That's a maturity story, not a walk-back — and it's exactly the kind of nuance a JVM audience will respect rather than a "BEAM does magic the JVM can't" overclaim.
- **For Gleam specifically.** Gleam compiles to standard BEAM bytecode, so the underlying two-versions-side-by-side mechanism applies to Gleam modules exactly as described — hot loading is a *runtime* property, inherited, not a language feature. What Gleam doesn't add is its own relup/release-upgrade tooling: a Gleam app that genuinely needs in-service upgrades leans on Erlang's release machinery (callable across the BEAM), while in everyday practice Gleam teams do what the rest of the ecosystem does — cheap rolling/blue-green restarts. Honest framing for the talk: *Gleam gets the capability for free from the BEAM; the intricate relup ergonomics simply aren't where Gleam's tooling is invested.*
- **Where to point the curious.** The REPL reload loop and `recon:remote_load` are the low-risk on-ramps; relups are the "do or die" deep end. Be clear which is which.

## Sources

Primary (Erlang/OTP & Elixir official docs):

- **Compilation and Code Loading — Erlang System Documentation** — https://www.erlang.org/doc/system/code_loading.html — *Authoritative source for the two-version (current/old) model, fully-qualified-vs-local call behavior, and third-load purge. Quoted directly throughout "Key facts."*
- **code — kernel (Erlang/OTP) reference** — https://www.erlang.org/doc/apps/kernel/code.html — *Verbatim definitions of `load_file/1`, `purge/1`, `soft_purge/1`, `load_binary/3`.*
- **gen_server — stdlib (Erlang/OTP) reference** — https://www.erlang.org/doc/apps/stdlib/gen_server.html — *`code_change/3` signature, semantics, upgrade/downgrade `OldVsn`, error-causes-rollback behavior.*
- **Release Handling — Erlang System Documentation** — https://www.erlang.org/doc/system/release_handling.html — *`.app`/`.rel`/`.appup`/`.relup`, `release_handler`, `systools:make_relup`, the suspend→change_code→purge→resume procedure, and the "many aspects can make release handling complicated" admission.*
- **mix release — Mix (Elixir) docs** — https://mix.hexdocs.pm/Mix.Tasks.Release.html (canonical link https://hexdocs.pm/mix/Mix.Tasks.Release.html, redirects) — *Official statement that hot upgrades are NOT supported out of the box, the complexity rationale, and the blue/green / canary / rolling recommendation.*

Secondary / community (cross-checks and practitioner consensus):

- **Learn You Some Erlang — "Relups"** — https://learnyousomeerlang.com/relups — *The blunt honesty: relups are among the most complex parts of OTP, the "do or die" recommendation, the Ericsson "as much time testing relups as the apps" remark, and the appup file shape.*
- **A Guide to Hot Code Reloading in Elixir — AppSignal Blog** — https://blog.appsignal.com/2021/07/27/a-guide-to-hot-code-reloading-in-elixir.html — *Hands-on mechanics: the two purge functions, why a `spawn` loop dies but a GenServer survives, `sys:change_code` / `code_change`, the "avoid home-brewed servers" advice.*
- **Best practices for deploying Elixir apps — Cogini** — https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/ — *Practitioner view: hot code updates listed under "things you probably don't need right now"; restart-the-release deployment model.*
- **All For Reliability: Reflections on the Erlang Thesis — DockYard** — https://dockyard.com/blog/2018/07/18/all-for-reliability-reflections-on-the-erlang-thesis — *AXD301 non-stop / in-service-upgrade design requirement, and the careful, skeptical framing of the "nine nines" claim.*
- **recon — Fred Hébert (docs + repo)** — https://ferd.github.io/recon/ and https://github.com/ferd/recon — *`remote_load/1,2` for diskless hot-patching of a live remote node; production-debugging context.*

JVM comparison:

- **JVM Tool Interface 1.2.3 (`RedefineClasses`) — Oracle** — https://docs.oracle.com/javase/8/docs/platform/jvmti/jvmti.html — *Verbatim restrictions (no add/remove/rename fields or methods, no signature/inheritance changes) and the stated dev-time / fix-and-continue intent.*
- **Java HotSwap Guide — JRebel / Perforce** — https://www.jrebel.com/blog/java-hotswap-guide — *HotSwap limitations and JRebel's classloader/instrumentation approach as a dev-productivity tool.*
- **HotswapAgent (DCEVM) — GitHub** — https://github.com/HotswapProjects/HotswapAgent — *DCEVM + HotswapAgent lifting standard HotSwap limits; still a non-standard VM aimed at development.*

Unverified / flagged:

- The **"nine nines" (99.9999999%)** AXD301 uptime figure is widely repeated but, per Armstrong's own thesis (via DockYard), poorly documented — present as anecdote, not metric.
- AXD301 **scale figures** (~2M LOC, ~160 Gbit/s) come from secondary/community sources; not cross-checked against a primary Ericsson document.
- The "purge twice" idiom and `?MODULE:` upgrade-point pattern are standard community practice (consistent with the docs' two-version model and fully-qualified-call rule) but are described here from common usage rather than a single quoted line.
