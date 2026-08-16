#!/usr/bin/env bash
# Opens et_viewer - Erlang/OTP's built-in sequence-chart tracer - connected
# into the running cluster. Every query/reply this demo sends is reported
# via `et:trace_me/5` (see src/cluster_fizzbuzz/trace.gleam); this GUI
# renders those events live as an actual sequence diagram, one column per
# node, a line drawn each time a message crosses between them.
#
# Run this *after* the central node and at least one query node are up.
#
# Both trace_global and trace_pattern are passed explicitly. This was
# confirmed by hand: trace_global alone does not turn on tracing -
# et_collector's trace_pattern option defaults to `undefined`, which means
# nothing gets traced regardless of trace_global, unless a pattern is given.
# {et, max} matches this demo's et:trace_me calls specifically.
#
# max_actors is raised well past its default of 5, so a swarm run doesn't
# get silently truncated to the first 5 node names seen.
#
# Requires the local Erlang/OTP build to include `wx` (GUI bindings) -
# check this ahead of time on the actual demo machine, not on stage.
#
# This prints connection/collector diagnostics to the terminal on purpose:
# if the chart window itself looks blank, these lines tell you whether the
# problem is "not connected to the cluster" / "tracing never started"
# versus "connected and capturing events, but the window isn't showing
# them" - two very different problems with different fixes.
set -euo pipefail
cd "$(dirname "$0")/.."

NODE_HOST="${NODE_HOST:-127.0.0.1}"
COOKIE="${COOKIE:-javazone_demo}"
CENTRAL_NODE="${CENTRAL_NODE:-central@${NODE_HOST}}"

erl -name "et_viewer@${NODE_HOST}" \
  -setcookie "${COOKIE}" \
  -noshell \
  -eval "
    Connected = net_kernel:connect_node(list_to_atom(\"${CENTRAL_NODE}\")),
    io:format(\"~n[et-viewer] connect_node(~s) -> ~p~n\", [\"${CENTRAL_NODE}\", Connected]),
    io:format(\"[et-viewer] nodes visible right now: ~p~n\", [nodes()]),
    {ok, _ViewerPid} = et_viewer:start([{trace_global, true}, {trace_pattern, {et, max}}, {max_actors, 30}]),
    timer:sleep(500),
    CollectorPid = et_collector:get_global_pid(),
    io:format(\"[et-viewer] collector pid: ~p (undefined here means tracing never started - see README troubleshooting)~n\", [CollectorPid]),
    timer:sleep(2000),
    Size0 = et_collector:get_table_size(CollectorPid),
    io:format(\"[et-viewer] events captured in the first 2s: ~p~n\", [Size0]),
    io:format(\"[et-viewer] if that number is 0 and query traffic is definitely flowing, something is genuinely wrong.~n\"),
    io:format(\"[et-viewer] if it is > 0, events ARE being captured - a blank window from here is a rendering/display issue, not a tracing one.~n\"),
    timer:sleep(3000),
    Size1 = et_collector:get_table_size(CollectorPid),
    io:format(\"[et-viewer] events captured after 5s total: ~p (should be higher than the first number)~n~n\", [Size1])
  "
