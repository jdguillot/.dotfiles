#!/usr/bin/env bash
# Applies the week's container bumps: every entry collect-container-signal.sh
# marked `changed`, minus what the model (or a dispatch) held, minus any
# whose target has no linux/amd64 image. There is no lock file to move --
# the tag in the native file is the pin -- so this edits those files in
# place: the `image:` line in a compose file, the option default in the
# immich module.
#
# Each edit is checked by reading the tag back the way the collector read
# it, so a line a staged branch changed since the scan is reported and left
# alone rather than half-edited. Per-entry failures are reported, never
# fatal: a container bump that cannot be applied must not cost the week its
# nix bump.
#
# Writes $APPLIED (default: containers-applied.json) for the pull request:
#   [{name, image, file, from, to, outcome, reason}]
set -uo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
containers="$OUT_DIR/containers.json"
verdict="$OUT_DIR/containers-verdict.json"
applied="${APPLIED:-containers-applied.json}"

echo '[]' > "$applied"
[ -s "$containers" ] || { echo "apply-containers: no $containers; nothing to apply"; exit 0; }
[ -s "$verdict" ] || echo '{"holds":[]}' > "$verdict"

held=$(jq -c '[.holds[].name]' "$verdict")
echo "held back: $(jq -r 'if length == 0 then "(nothing)" else join(" ") end' <<<"$held")"

ere_escape() { printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g'; }
# Same template rule as the collector: prefix and suffix around @TAG@, both
# escaped; the old tag is matched exactly so only the pinned line changes.
rewrite() {
  local file="$1" tmpl="$2" from="$3" to="$4" prefix suffix
  prefix=$(ere_escape "${tmpl%%@TAG@*}")
  suffix=$(ere_escape "${tmpl#*@TAG@}")
  sed -i -E "s/(${prefix})$(ere_escape "$from")(${suffix})/\1${to}\2/" "$file"
}
tag_lines() {
  local file="$1" tmpl="$2" prefix suffix
  prefix=$(ere_escape "${tmpl%%@TAG@*}")
  suffix=$(ere_escape "${tmpl#*@TAG@}")
  sed -nE "s/^.*${prefix}([A-Za-z0-9_][A-Za-z0-9._-]*)${suffix}.*$/\1/p" "$file"
}

record() {  # name image file from to outcome reason
  jq --arg n "$1" --arg i "$2" --arg f "$3" --arg a "$4" --arg b "$5" --arg o "$6" --arg r "$7" \
    '. + [{ name: $n, image: $i, file: $f, from: $a, to: $b, outcome: $o, reason: $r }]' \
    "$applied" > "$applied.new" && mv "$applied.new" "$applied"
}

done_names='[]'
while IFS=$'\t' read -r name image file from to ok follows; do
  tmpl=$(jq -r --arg n "$name" '.[] | select(.name == $n) | .line // "image: @IMAGE@:@TAG@"' "$containers")
  tmpl="${tmpl//@IMAGE@/$image}"

  if jq -e --arg n "$name" 'index($n)' <<<"$held" >/dev/null; then
    reason=$(jq -r --arg n "$name" '[.holds[] | select(.name == $n) | .reason] | first // ""' "$verdict")
    echo "  hold  $name: $reason"
    record "$name" "$image" "$file" "$from" "$to" held "$reason"
    continue
  fi
  if [ "$ok" = false ]; then
    echo "  skip  $name: the target has no linux/amd64 image"
    record "$name" "$image" "$file" "$from" "$to" skipped "no linux/amd64 image behind $to"
    continue
  fi
  # A follower moves only with the entry it follows: Immich's Postgres tag
  # is the one its compose names beside the server release being taken.
  if [ -n "$follows" ] && [ "$follows" != null ] \
     && jq -e --arg f "$follows" 'any(.[]; .name == $f and .state == "changed")' "$containers" >/dev/null \
     && ! jq -e --arg f "$follows" 'index($f)' <<<"$done_names" >/dev/null; then
    echo "  skip  $name: follows $follows, which was not bumped"
    record "$name" "$image" "$file" "$from" "$to" skipped "follows $follows, which was held or skipped"
    continue
  fi
  # Registry tags are [A-Za-z0-9_][A-Za-z0-9._-]*, so a target outside that
  # never came from a registry and is not going into a sed replacement.
  if ! [[ "$to" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
    echo "  skip  $name: target '$to' is not a tag"
    record "$name" "$image" "$file" "$from" "$to" skipped "target is not a valid tag"
    continue
  fi
  if [ "$(tag_lines "$file" "$tmpl" | grep -cx "$from")" -ne 1 ]; then
    echo "  skip  $name: $file no longer has exactly one line pinning $from (changed since the scan?)"
    record "$name" "$image" "$file" "$from" "$to" skipped "the pinned line in $file is not what the scan read"
    continue
  fi

  rewrite "$file" "$tmpl" "$from" "$to"
  if [ "$(tag_lines "$file" "$tmpl" | grep -cx "$to")" -eq 1 ]; then
    echo "  bump  $name: $from -> $to in $file"
    record "$name" "$image" "$file" "$from" "$to" bumped ""
    done_names=$(jq -c --arg n "$name" '. + [$n]' <<<"$done_names")
  else
    echo "  fail  $name: the edit did not take in $file"
    git checkout -- "$file" 2>/dev/null || true
    record "$name" "$image" "$file" "$from" "$to" skipped "the edit did not take; the file was restored"
  fi
done < <(jq -r '.[] | select(.state == "changed")
  | [.name, .image, .file, .current, .target, (.platform_ok // true | tostring), (.follows // "")] | @tsv' "$containers")

n_bumped=$(jq '[.[] | select(.outcome == "bumped")] | length' "$applied")
n_other=$(jq '[.[] | select(.outcome != "bumped")] | length' "$applied")
if [ "$n_bumped" -gt 0 ] || [ "$n_other" -gt 0 ]; then
  {
    echo "## Container images"
    echo ""
    echo "| Container | Image | From | To | Outcome |"
    echo "|---|---|---|---|---|"
    jq -r '.[] | "| `\(.name)` | `\(.image)` | \(.from) | \(.to) | "
      + (if .outcome == "bumped" then "bumped" else "**\(.outcome)**: \(.reason)" end) + " |"' "$applied"
    echo ""
  } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
fi
if [ "$n_other" -gt 0 ]; then
  echo "::warning::$n_other container bump(s) not applied: $(jq -r '[.[] | select(.outcome != "bumped") | .name] | join(", ")' "$applied")"
fi

git --no-pager diff --stat -- $(jq -r '[.[] | select(.outcome == "bumped") | .file] | unique | .[]' "$applied") 2>/dev/null || true
