#!/usr/bin/env bash
# Starts a querying node that asks the central node fizzbuzz questions.
# Run the central node first (scripts/run-central.sh), then one of these
# per extra terminal, with a distinct label.
#
# Usage: scripts/run-node.sh <label>
# Example: scripts/run-node.sh node2
#
# Recognised labels with their own terminal colour: node2, node3, node4,
# node5 (see src/cluster_fizzbuzz/colors.gleam). Any other label still
# works, just in the default colour.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "Usage: $0 <label>" >&2
  exit 1
fi

LABEL="$1"
NODE_HOST="${NODE_HOST:-127.0.0.1}"
COOKIE="${COOKIE:-javazone_demo}"
CENTRAL_NODE="${CENTRAL_NODE:-central@${NODE_HOST}}"

gleam build

EBIN_PATHS=$(find build/dev/erlang -maxdepth 2 -type d -name ebin | sed 's/^/-pa /' | tr '\n' ' ')

# shellcheck disable=SC2086
exec erl $EBIN_PATHS \
  -name "${LABEL}@${NODE_HOST}" \
  -setcookie "${COOKIE}" \
  -noshell \
  -eval 'cluster_fizzbuzz:main().' \
  -extra query "${LABEL}" "${CENTRAL_NODE}"
