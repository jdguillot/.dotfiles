#!/usr/bin/env bash
# Cancels a pending auto-reboot and holds it off for a while.
#
# Usage: reboot-postpone [duration]     # anything `date -d "now + X"` accepts
#
# The budget stops a machine being deferred forever by someone who never
# looks at the wall message again. It resets when a reboot actually happens,
# because auto-reboot.sh clears the state directory on its way out.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "reboot-postpone must run as root (try: sudo reboot-postpone $*)" >&2
  exit 1
fi

dur="${1:-@DEFAULT@}"
state=@STATE@
count_file="$state/postpone-count"
until_file="$state/postponed-until"

mkdir -p "$state"
count=$(cat "$count_file" 2>/dev/null || echo 0)
if [ "$count" -ge "@MAX@" ]; then
  echo "already postponed $count times (limit @MAX@); reboot when you can, or" >&2
  echo "clear $count_file to override." >&2
  exit 1
fi

if ! until_ts=$(date -d "now + $dur" +%s 2>/dev/null); then
  echo "cannot parse duration '$dur' -- try something like '2h' or '30min'" >&2
  exit 1
fi

# -c is harmless when nothing is scheduled, which is the case when someone
# postpones ahead of the timer rather than in response to the warning.
@SHUTDOWN@ -c 2>/dev/null || true
echo "$until_ts" > "$until_file"
echo $((count + 1)) > "$count_file"

echo "reboot postponed until $(date -d "@$until_ts") ($((count + 1))/@MAX@)"
