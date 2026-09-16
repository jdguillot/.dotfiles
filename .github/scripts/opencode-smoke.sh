#!/usr/bin/env bash
# Proves the opencode on this runner can do what the fix agent will ask of
# it -- the same config, the 27B, the build agent with every tool -- before
# the week's bump relies on it.
#
# Worth its own step because the fix stage is the only thing that runs
# opencode and it only runs after a build has already failed -- so a broken
# opencode is found at the worst possible moment, as an hour of nothing. It
# got there once: nixpkgs shipped 1.18.30, which throws in
# SystemPrompt.environment on every prompt, and the bump that introduced it
# passed every gate. No build can catch that; the package builds fine.
#
# A real round trip, because opencode can break anywhere on that path --
# before the request, reading the stream, handling the reply -- and only
# the full path covers all of it. What it must not do is read a slow model
# as a broken opencode: the GPU is shared, and a reply once took seven
# minutes. opencode's own logs separate the two. A request that went out
# and is still waiting is the model's time, not opencode's failure.
#
# Exit 0  a reply came back through opencode
# Exit 1  opencode failed: it errored, or exited without replying
# Exit 3  unverified: the request went out cleanly but no reply came back
#         in time; opencode got as far as a busy model lets it
set -uo pipefail

CONFIG="${OPENCODE_SMOKE_CONFIG:-.github/opencode/opencode.json}"
TIMEOUT="${OPENCODE_SMOKE_TIMEOUT:-180}"
CACHE_HOME="${OPENCODE_SMOKE_CACHE:-}"
# Distinctive enough that it cannot appear by chance in an error banner.
SENTINEL="opencode-smoke-ok"

command -v opencode >/dev/null 2>&1 || {
  echo "opencode-smoke: opencode is not on PATH"
  exit 1
}

work=$(mktemp -d)
pid=""
# shellcheck disable=SC2329 # invoked by the trap
cleanup() {
  # Waited on, not just signalled: opencode is still writing its caches as
  # it exits, and removing the directory underneath it races that.
  if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null
  fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/home/.config/opencode" "$work/empty"
[ -n "$CACHE_HOME" ] || CACHE_HOME="$work/home/.cache"
mkdir -p "$CACHE_HOME"

# Same MCP rule as the fix step: kept when the server is on PATH, dropped
# when it is not, so this tests the configuration the agent will really get.
if command -v mcp-nixos >/dev/null 2>&1; then
  cp "$CONFIG" "$work/home/.config/opencode/opencode.json"
else
  jq 'del(.mcp)' "$CONFIG" > "$work/home/.config/opencode/opencode.json"
fi || {
  echo "opencode-smoke: could not read $CONFIG"
  exit 1
}

# The reply on stdout, the logs on stderr: the logs are how a waiting
# request is told apart from a failed one, and keeping them apart means the
# sentinel can only match the model's answer.
out="$work/out.txt"
log="$work/log.txt"
HOME="$work/home" \
XDG_CONFIG_HOME="$work/home/.config" \
XDG_CACHE_HOME="$CACHE_HOME" \
OPENCODE_CONFIG="$work/home/.config/opencode/opencode.json" \
  opencode run --pure --print-logs --dir "$work/empty" --agent build \
  "Reply with exactly this word and nothing else: $SENTINEL" \
  > "$out" 2> "$log" &
pid=$!

state=waiting
for _ in $(seq "$TIMEOUT"); do
  if grep -qF "$SENTINEL" "$out"; then
    state=passed
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    # One last look: the reply and the exit can land in the same second.
    grep -qF "$SENTINEL" "$out" && state=passed || state=failed
    break
  fi
  sleep 1
done

version=$(opencode --version 2>/dev/null)
tail_of() {
  echo "--- last 30 lines ---"
  cat "$out" "$log" | grep -v '^\s*$' | tail -n 30 | cut -c1-400
}

# The build agent's request having gone out is the line that only exists
# once the whole prompt, tools included, was assembled and sent.
sent() { grep -q 'message=stream .*agent=build' "$log"; }
errored() { grep -q 'level=ERROR' "$log"; }

case "$state" in
  passed)
    echo "opencode-smoke: $version answered through the build agent"
    exit 0
    ;;
  failed)
    echo "opencode-smoke: $version exited without answering"
    tail_of
    exit 1
    ;;
esac

# Still running at the deadline.
if errored || ! sent; then
  echo "opencode-smoke: $version had not answered after ${TIMEOUT}s and" \
    "$(errored && echo "logged errors" || echo "never sent the request")"
  tail_of
  exit 1
fi
echo "opencode-smoke: $version sent the request cleanly, but the model had" \
  "not answered after ${TIMEOUT}s; the reply path is unverified"
exit 3
