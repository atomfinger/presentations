# snippets

Small, standalone Gleam modules written for JavaZone 2026 ("Beam and
Gleam") slides - not a package, and not meant to demonstrate a full running
system the way `supervision_demo` and `cluster_fizzbuzz` do.

## Why this exists, separately from the other two demo projects

Slide code needs to be trustworthy in a different way than a live demo
does: it's never actually run in front of the audience, so the only thing
protecting you from showing a snippet that's subtly wrong - or that used to
compile against an older Gleam/OTP version and quietly doesn't anymore - is
whether it's still real, buildable code. Each module here is exactly what
gets shown on a slide, nothing extra, with a test file next to it that
proves the snippet does what the talk claims it does before it ever goes
on screen.

## What's here

These three build on each other on purpose, in this order, mirroring how
the talk builds the same argument live: start with the smallest possible
thing, then add exactly one capability at a time, in a handful of lines
each, rather than introducing a whole new unrelated concept per slide.

- `src/fan_out.gleam` - the simplest possible fan-out: a process holding a
  list of subscribers, and a `Publish` that sends one event to every one
  of them. No queue library, no broker, no separate infrastructure to
  stand up - just a process and a list. This is the concrete code behind
  the "do you really need Kafka to tell three things this happened?" beat
  in the talk.

  Tests (`test/fan_out_test.gleam`) check: every subscriber gets a
  published event, a subscriber that joins *after* an event was published
  does not receive that old event (this fan-out has no history/replay -
  worth being upfront about if asked), and publishing to zero subscribers
  doesn't crash the process.

- `src/persisted_fan_out.gleam` - the exact same fan-out, plus one extra
  line on `Publish`: every event also gets written to Mnesia,
  Erlang/OTP's built-in distributed database - no separate service to
  install or run. This is the concrete code behind the talk's "need it to
  be persisted? Use the built-in distributed database" line. Runs
  entirely in memory (no schema file, no disc storage), so it's safe to
  run repeatedly without leaving anything behind.

  Since Gleam doesn't wrap Mnesia directly, `src/persisted_fan_out_ffi.erl`
  is a small hand-written Erlang shim around `mnesia:start/0`,
  `mnesia:create_table/2`, and a transactional write/read - the same
  "drop to a raw primitive on purpose, at exactly one seam" pattern used
  in `cluster_fizzbuzz` for `global`.

  Tests (`test/persisted_fan_out_test.gleam`) check: live subscribers
  still get published events as before, published events are actually
  retained in Mnesia afterward, and - the punchline - a subscriber that
  joins *late* can catch up by reading history back out of Mnesia, which
  is the one thing the plain `fan_out` explicitly cannot do.

- `src/acked_fan_out.gleam` - one more step on top of `persisted_fan_out`,
  not a separate idea: the same Mnesia-backed publish, plus a guarantee
  that a subscriber actually got the message - send, wait for an `Ack`
  reply, and retry a few times before giving up on that one subscriber.
  Still no message broker, no delivery-tracking service - a reply message
  and a loop, reusing the exact same Mnesia table `persisted_fan_out`
  already set up (via the same `persisted_fan_out_ffi` module). This is
  the concrete code behind the talk's "need guarantees of retrieval?
  Implement a simple 'ack' callback" line, presented as the natural next
  few lines rather than a new topic.

  Tests (`test/acked_fan_out_test.gleam`) use a small "flaky" subscriber
  process that only acknowledges after a configurable number of attempts,
  to check: a subscriber that acks immediately gets the event exactly
  once, a flaky subscriber gets retried until it finally acks (with the
  exact attempt count asserted, not just the end result), and publishing
  still persists to Mnesia alongside the ack guarantee. One real bug this
  caught while writing it: a `Subject` is owned by whichever process
  creates it, and only the owner may `receive` on it - the flaky
  subscriber has to create its own subject and hand it back to the test,
  rather than receiving on one the test created for it, or every attempt
  panics instead of timing out.

- `src/reset_password_use.gleam` - deliberately **not** a real
  implementation. Every validation step (`parse`, `find_registration`,
  `require_verified`, `send_password_reset`) is a `todo` stub - the point
  isn't email validation, it's showing what chaining several
  Result-returning steps actually looks like wired together, using `use`
  with `result.try`, instead of the nested `case` pyramid you'd get
  unwrapping each `Result` by hand. Reuses the exact
  `Email -> RegisteredEmail -> VerifiedEmail` chain from the Typing
  section's smart-constructor example - this is that same chain, actually
  called in sequence, for the "doesn't all this Result stuff get
  cumbersome?" answer in the Errors section.

  No test file for this one, on purpose: every function is a `todo`, so
  calling any of them crashes by design (verified by hand while writing
  it - `reset_password("test@example.com")` compiles clean and then
  crashes exactly at the first `todo`, with its message, the moment
  `main` actually calls it). There's no real behaviour here to assert
  against - `gleam build` succeeding *is* the check for a slide whose
  only job is to type-check and show the shape of `use`.

## Development

```sh
gleam build  # Compile
gleam test   # Run the tests
```
