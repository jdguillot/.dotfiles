#!/usr/bin/env bash
# WORKAROUND(immich-ml-memory-leak)
# Restarts immich-server before the cgroup OOM-killer does. Immich v3.2.0
# never releases remote ML response bodies, so the node process grows with
# every asset sent to ML; a SIGTERM restart beats a SIGKILL mid-job.
set -euo pipefail

container=immich-server
limit_kb=$((@LIMIT_MB@ * 1024))

id=$(@DOCKER@ inspect --format '{{.Id}}' "$container" 2>/dev/null) || exit 0
procs=/sys/fs/cgroup/system.slice/docker-$id.scope/cgroup.procs
[ -r "$procs" ] || exit 0

# `immich` is the node server; `immich-api` and the exiftool workers stay small.
rss=0
while read -r pid; do
  [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = immich ] || continue
  kb=$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
  [ "${kb:-0}" -gt "$rss" ] && rss=$kb
done <"$procs"

[ "$rss" -ge "$limit_kb" ] || exit 0

started=$(@DOCKER@ inspect --format '{{.State.StartedAt}}' "$container")
uptime=$(($(date +%s) - $(date -d "$started" +%s)))
if [ "$uptime" -lt @MIN_UPTIME@ ]; then
  echo "immich RSS $((rss / 1024))M over @LIMIT_MB@M but up only ${uptime}s; not restarting"
  exit 0
fi

echo "immich RSS $((rss / 1024))M over @LIMIT_MB@M after ${uptime}s; restarting $container"
@DOCKER@ restart --time 60 "$container"
# END WORKAROUND(immich-ml-memory-leak)
