#!/usr/bin/env bash
# Opens Erlang/OTP's built-in :observer GUI, connected into the running
# cluster, so you can watch the "Nodes" tab and process list live.
#
# Run this *after* the central node and at least one query node are already
# up. It starts a small extra node purely to host the GUI and connects it
# into the cluster - it doesn't run any fizzbuzz code itself.
#
# Requires the local Erlang/OTP build to include `wx` (GUI bindings). If
# `:observer.start()` errors immediately, that's almost certainly why -
# check on the actual demo machine ahead of time, not on stage.
set -euo pipefail
cd "$(dirname "$0")/.."

NODE_HOST="${NODE_HOST:-127.0.0.1}"
COOKIE="${COOKIE:-javazone_demo}"
CENTRAL_NODE="${CENTRAL_NODE:-central@${NODE_HOST}}"

erl -name "observer@${NODE_HOST}" \
  -setcookie "${COOKIE}" \
  -eval "net_kernel:connect_node(list_to_atom(\"${CENTRAL_NODE}\")), observer:start()."

# For the sequence-chart view (lines drawn between nodes as messages
# cross), see scripts/et-viewer.sh instead of/alongside this.
