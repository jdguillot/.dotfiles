#!/usr/bin/env bash
# Checks that the tools a job is about to use are actually on the runner's
# PATH, and says what to do about it if they are not.
#
# Worth a script of its own because the failure it replaces is genuinely
# confusing: the runner's PATH is deliberately near-empty and comes from
# `github-runner.extraPackages` on ryzn-server, so adding a tool to a
# workflow does nothing until that host is rebuilt. Without this you get
# `jq: command not found` on some line deep in another script, and nothing
# anywhere connects that to a pending nixos-rebuild.
#
# Tools after a lone `--` are optional: their absence is reported and the job
# carries on. That is for things a step is better with but can run without --
# an MCP server the fix agent consults, say. A missing optional tool must not
# be the reason a week's bump does not happen.
#
# It also refuses to start on a nearly full disk: a job that fills the disk
# mid-build crashes the runner worker, which loses the job log and the
# reason. Failing here keeps both.
#
# Usage: preflight.sh gh jq curl -- mcp-nixos
# PREFLIGHT_MIN_FREE_GB (default 15) sets the free-space floor.
set -euo pipefail

min_free_gb=${PREFLIGHT_MIN_FREE_GB:-15}
low_disk=()
seen_mounts=" "
for path in /nix/store "$PWD" ${RUNNER_TEMP:+"$RUNNER_TEMP"}; do
  [ -d "$path" ] || continue
  # The runners' work dir is on /run: RAM, sized well under the floor and
  # wiped per job, and it cannot fill the disk.
  [ "$(stat -f -c %T "$path")" = tmpfs ] && continue
  read -r avail_kb mount < <(df -Pk "$path" | awk 'NR==2 {print $4, $6}')
  case "$seen_mounts" in *" $mount "*) continue ;; esac
  seen_mounts+="$mount "
  free_gb=$((avail_kb / 1024 / 1024))
  printf '  %-10s %s GiB free on %s\n' "disk" "$free_gb" "$mount"
  if [ "$free_gb" -lt "$min_free_gb" ]; then
    low_disk+=("\`$mount\`: ${free_gb} GiB free")
  fi
done

missing=()
absent_optional=()
optional=false
for t in "$@"; do
  if [ "$t" = "--" ]; then
    optional=true
    continue
  fi
  if command -v "$t" >/dev/null 2>&1; then
    printf '  %-10s %s\n' "$t" "$(command -v "$t")"
  elif [ "$optional" = true ]; then
    printf '  %-10s (optional, absent)\n' "$t"
    absent_optional+=("$t")
  else
    missing+=("$t")
  fi
done

if [ ${#low_disk[@]} -gt 0 ]; then
  {
    echo "## Runner disk is nearly full"
    echo ""
    echo "Below the ${min_free_gb} GiB floor this job needs:"
    echo ""
    printf -- '- %s\n' "${low_disk[@]}"
    echo ""
    echo "Nix's \`min-free\` collection only reclaims dead store paths. Find what"
    echo "grew on the host (\`sudo du -xh --max-depth=2 /home /var/lib | sort -h\`),"
    echo "free it, then rerun the job."
  } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
  echo "::error::runner disk below ${min_free_gb} GiB free -- see the job summary"
  exit 1
fi

if [ ${#absent_optional[@]} -gt 0 ]; then
  echo "::warning::runner is missing optional ${absent_optional[*]} -- continuing without"
fi

if [ ${#missing[@]} -gt 0 ]; then
  {
    echo "## Runner is missing tools"
    echo ""
    echo "Not on this job's PATH: \`${missing[*]}\`"
    echo ""
    echo "The runner PATH comes from \`cyberfighter.features.github-runner.extraPackages\`"
    echo "on \`ryzn-server\`. If these are already listed there, that host has not been"
    echo "rebuilt since they were added:"
    echo ""
    echo '```'
    echo "deploy .#ryzn-server.system --remote-build"
    echo '```'
    echo ""
    echo "If it was rebuilt just now, rerun the job: a switch does not restart the"
    echo "runners, so each takes the new PATH only after finishing a job -- this one counts."
  } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
  echo "::error::runner is missing ${missing[*]} -- see the job summary"
  exit 1
fi
