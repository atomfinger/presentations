#!/usr/bin/env bash
# Starts a swarm of many querying nodes at once, to show the cluster
# scaling past "two or three nodes I'm narrating out loud" - a couple of
# dozen separate BEAM processes all finding and querying the same central
# node, unattended.
#
# Run scripts/run-central.sh first.
#
# Usage: scripts/run-swarm.sh [count]
# Example: scripts/run-swarm.sh 20   (20 is also the default if omitted)
#
# Each swarm node is labelled swarm1, swarm2, ... swarmN (kept distinct
# from the node2/node3 you narrate by hand, so they don't collide) and logs
# to its own file under logs/, not the terminal - twenty scrolling
# terminals is not a demo, it's a cry for help. Stop them all with
# scripts/stop-swarm.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

COUNT="${1:-20}"
NODE_HOST="${NODE_HOST:-127.0.0.1}"
COOKIE="${COOKIE:-javazone_demo}"
CENTRAL_NODE="${CENTRAL_NODE:-central@${NODE_HOST}}"

gleam build

EBIN_PATHS=$(find build/dev/erlang -maxdepth 2 -type d -name ebin | sed 's/^/-pa /' | tr '\n' ' ')

mkdir -p logs
: > logs/swarm.pids

echo "Starting ${COUNT} swarm nodes against ${CENTRAL_NODE}..."

for i in $(seq 1 "$COUNT"); do
  LABEL="swarm${i}"
  # shellcheck disable=SC2086
  erl $EBIN_PATHS \
    -name "${LABEL}@${NODE_HOST}" \
    -setcookie "${COOKIE}" \
    -noshell \
    -eval 'cluster_fizzbuzz:main().' \
    -extra query "${LABEL}" "${CENTRAL_NODE}" \
    > "logs/${LABEL}.log" 2>&1 &
  echo $! >> logs/swarm.pids
done

echo "All ${COUNT} swarm nodes started (PIDs in logs/swarm.pids)."
echo "Tail one with:      tail -f logs/swarm1.log"
echo "See them connect:   scripts/observe.sh   (Nodes tab should show ${COUNT} extra nodes)"
echo "Stop them all with:  scripts/stop-swarm.sh"
