#!/usr/bin/env bash
# Starts the central fizzbuzz node. Run this first, in its own terminal.
#
# Usage: scripts/run-central.sh
#
# Override the node host/cookie by exporting NODE_HOST / COOKIE before
# running if 127.0.0.1 or the default cookie don't suit your setup.
set -euo pipefail
cd "$(dirname "$0")/.."

NODE_HOST="${NODE_HOST:-127.0.0.1}"
COOKIE="${COOKIE:-javazone_demo}"

gleam build

EBIN_PATHS=$(find build/dev/erlang -maxdepth 2 -type d -name ebin | sed 's/^/-pa /' | tr '\n' ' ')

# shellcheck disable=SC2086
exec erl $EBIN_PATHS \
  -name "central@${NODE_HOST}" \
  -setcookie "${COOKIE}" \
  -noshell \
  -eval 'cluster_fizzbuzz:main().' \
  -extra central
