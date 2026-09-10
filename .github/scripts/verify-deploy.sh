#!/usr/bin/env bash
# Reports whether the commit CI just published actually reached every host.
#
# The agent is the source of truth. `deptui-agent status --json` carries the
# revision each host last deployed, so this needs neither ssh to the fleet
# nor a secret: the control socket the kick already uses is enough (socket
# access comes from github-runner.extraGroups on ryzn-server).
#
# A kick only queues a poll, so this cannot watch for a run to appear and
# then end -- it would race and report the previous revision. It waits on the
# per-host state instead: a host is settled once it has deployed this
# revision, or reached a state that will not change without a human (failed
# or held at this revision, paused).
#
# Not reaching a host is a warning, never a failure. The build, the checks
# and the cache push all succeeded; a held or offline host is an operational
# matter, not a broken tree, and failing here would make the run red for
# something a later kick fixes on its own.
#
# Usage: verify-deploy.sh [rev]        # default: $GITHUB_SHA
#   VERIFY_TIMEOUT   seconds to wait for stragglers (default 900)
#   VERIFY_INTERVAL  seconds between polls (default 15)
set -euo pipefail

rev="${1:-${GITHUB_SHA:?no revision given and GITHUB_SHA is unset}}"
timeout="${VERIFY_TIMEOUT:-900}"
interval="${VERIFY_INTERVAL:-15}"
short="${rev:0:12}"

# Hosts that have neither taken this revision nor parked at it. Paused hosts
# are excluded deliberately: a pause is a human saying "not this one".
# Offline counts as parked too -- the agent re-probes it on its own schedule,
# which is far longer than this job should hold a runner for.
unsettled() {
  jq --arg rev "$rev" '
    [ .watches[].hosts[]
      | select(.paused | not)
      | select(.deployed_rev != $rev)
      | select(.failed_rev != $rev)
      | select(.held_rev != $rev)
      | select(.offline_rev != $rev)
    ] | length' <<<"$1"
}

deadline=$(( $(date +%s) + timeout ))
while :; do
  status=$(deptui-agent status --json)
  [ "$(unsettled "$status")" -eq 0 ] && break
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "::warning::hosts still working ${timeout}s after the kick; reporting what has landed"
    break
  fi
  sleep "$interval"
done

# One row per (watch, host). `offline_rev` is reported before the catch-all
# because an unreachable host is the common benign case and says so; the
# catch-all is for a host the agent simply has not got to yet.
rows=$(jq -r --arg rev "$rev" '
  .watches[] as $w
  | $w.hosts[]
  | [ .name,
      $w.name,
      ( if .deployed_rev == $rev then "switched"
        elif .paused then "paused"
        elif .failed_rev == $rev then "failed"
        elif .held_rev == $rev then "held"
        elif .offline_rev == $rev then "offline"
        else "no result" end ),
      ( if .deployed_rev == $rev then ""
        elif .paused then "deploys paused for this host"
        elif .failed_rev == $rev then (.failed_message // "no message")
        elif .held_rev == $rev then "approve to let the next round deploy it"
        elif .offline_rev == $rev then
          ( "unreachable"
            + (if .offline_denied then " (connection refused)" else "" end)
            + "; retried automatically when it answers" )
        else "last deployed " + ((.deployed_rev // "never")[0:12]) end )
    ] | @tsv' <<<"$status")

{
  echo "## Did the fleet take \`$short\`?"
  echo ""
  echo "| Host | Watch | State | Detail |"
  echo "|---|---|---|---|"
  while IFS=$'\t' read -r host watch state detail; do
    icon=$([ "$state" = switched ] && echo "✅" || echo "⚠️")
    echo "| \`$host\` | \`$watch\` | $icon $state | $detail |"
  done <<<"$rows"
  echo ""
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# paste -s cycles through a multi-char delimiter list one char at a time, so
# the join is done here instead.
behind=$(awk -F'\t' '$3 != "switched" { printf "%s%s (%s)", sep, $1, $3; sep = ", " }' <<<"$rows")
if [ -n "$behind" ]; then
  echo "::warning::did not take ${short}: ${behind}"
else
  echo "every host is on ${short}"
fi
