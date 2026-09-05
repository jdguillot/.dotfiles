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
# Usage: preflight.sh gh jq curl -- mcp-nixos
set -euo pipefail

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
  } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
  echo "::error::runner is missing ${missing[*]} -- see the job summary"
  exit 1
fi
