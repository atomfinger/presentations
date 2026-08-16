# supervision_demo

A talk demo for JavaZone 2026 ("Beam and Gleam"). Not a package, just a
runnable illustration of "let it crash."

## What it does

- Starts an OTP `static_supervisor` (`OneForOne` strategy) watching three
  named workers: `worker-a`, `worker-b`, `worker-c`.
- Simulates traffic: once every 500ms, a fake "request" is sent to a randomly
  chosen worker.
- Each worker has roughly a 1-in-6 chance of hitting a `panic` while handling
  a request - a simulated bug, nothing more.
- A small dashboard actor redraws a live, in-place table every 250ms -
  deliberately styled like `kubectl get pods` under `watch`:

  ```
  Beam supervision demo - live worker fleet (Ctrl+C to stop)

  NAME          STATUS              RESTARTS  LAST REQUEST
  worker-a      ✓ Running           1         #18 ok
  worker-b      ✗ Crashed           0         #17 panic
  worker-c      ✓ Running           1         #19 ok
  ```

  A worker flips to a red `✗ Crashed` the instant it panics, stays that way
  through the actual crash and restart (which is far faster than the
  redraw), and flips back to green `✓ Running` once it successfully handles
  its next request - the same "restart, then prove you're healthy" arc
  you'd watch for in a `kubectl get pods` output, just for BEAM processes
  instead of containers.

## Running it

```sh
gleam run
```

Just let it sit and watch the table. Stop it with Ctrl+C.

## What to call out live

- This is the exact same shape as the `kubectl get pods` table everyone in
  the audience already reads instinctively - READY/STATUS/RESTARTS/AGE. The
  point isn't that Beam invented this idea, it's that the same "did it come
  back, and how many times has it had to" question applies one level below
  Kubernetes, to individual processes, and the supervisor answers it in
  milliseconds instead of the seconds-to-tens-of-seconds a pod restart takes.
- The RESTARTS column only increments once a crashed worker's replacement
  has actually started - mirroring what `kubectl`'s own RESTARTS column
  counts.
- Nothing in the traffic simulator ever needed a null check, a try/catch, or
  an "is this worker still alive" ping before sending a request - it just
  keeps addressing the same worker name throughout.

## Deliberately out of scope

This demo does not showcase OTP's restart-intensity escalation (a supervisor
giving up after too many crashes too fast) - `restart_tolerance` is cranked
up specifically to avoid that happening mid-demo. The talk script covers
that mechanism as a spoken explanation instead; this demo is scoped to the
simple, core loop only.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
