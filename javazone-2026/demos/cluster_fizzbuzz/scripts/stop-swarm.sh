#!/usr/bin/env bash
# Stops every swarm node started by scripts/run-swarm.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f logs/swarm.pids ]; then
  echo "No logs/swarm.pids found - nothing to stop (was run-swarm.sh ever run?)." >&2
  exit 0
fi

count=0
while read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    count=$((count + 1))
  fi
done < logs/swarm.pids

rm -f logs/swarm.pids
echo "Stopped ${count} swarm node(s)."
