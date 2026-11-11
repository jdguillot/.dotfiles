#!/usr/bin/env bash
# Lists every root flake input and npins pin the working tree moved relative
# to a base ref, one per line with short old -> new revisions. The fix agent
# reads it so its notes name what moved instead of inferring it from the
# failure, and so it never mistakes a transitive `nixpkgs` node for the root's.
#
# Usage: changed-inputs.sh [<base ref>]   (default: origin/main)
set -euo pipefail

base="${1:-origin/main}"

jq -rn --argjson old "$(git show "$base:flake.lock")" --slurpfile new flake.lock '
  $new[0] as $new |
  def at($l; $k): ($l.nodes[$l.root].inputs[$k] // null | if type == "array" then .[0] else . end) as $n
    | if $n == null then null else ($l.nodes[$n].locked | .rev // .narHash) end;
  $new.nodes[$new.root].inputs | keys[] as $k
  | [at($old; $k), at($new; $k)] | select(.[0] != .[1])
  | "flake input \($k): \(.[0] // "added" | .[0:12]) -> \(.[1] // "removed" | .[0:12])"'

if [ -f npins/sources.json ]; then
  jq -rn --argjson old "$(git show "$base:npins/sources.json" 2>/dev/null || echo '{"pins":{}}')" \
         --slurpfile new npins/sources.json '
    $new[0].pins | to_entries[] | select(.value.revision != ($old.pins[.key].revision // null))
    | "npins \(.key): \($old.pins[.key].revision // "added" | .[0:12]) -> \(.value.revision // "?" | .[0:12])"'
fi
