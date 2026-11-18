#!/usr/bin/env bash
# The top of the weekly pull request: what needs a person before the merge,
# and what the run could not see.
#
# Nothing here is judged. Every line is a fact another script already
# recorded as JSON -- a driver version that moved, a release-note section
# upstream headed "Action required", a hold, a probe that did not answer --
# gathered into one list so the body does not have to be read to the end to
# find the three lines that matter. When both lists are empty the block
# says so and names what was checked, which is the only state in which the
# rest of the body is optional reading.
#
# The second list matters as much as the first. Every model call and most
# collectors here fail open, so a week where the evidence was missing looks
# exactly like a week where it was clean unless something says otherwise.
#
# Usage: needs-attention.sh [<upstream-signal dir> [<update-report dir>]]
# Env:   CACHED   the cache job's result (success / failure / skipped)
# Markdown on stdout. Missing files are skipped or reported, never fatal.
set -euo pipefail

sig="${1:-upstream-signal}"
rep="${2:-update-report}"

act=()
blind=()

# Present, and for JSON also parseable: a file a step was killed while
# writing must read as missing evidence, not as an empty result.
declare -A invalid=()
has() {
  [ -s "$1" ] || return 1
  case "$1" in
    *.json) jq empty "$1" >/dev/null 2>&1 || { invalid["${1##*/}"]=1; return 1; } ;;
  esac
}
# Appends each line of stdin to the named array.
into() {
  local -n arr="$1"
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && arr+=("$line")
  done
  return 0
}

# ---------------------------------------------------------------- applying
if has "$rep/reboot.json"; then
  into act < <(jq -r '.[]
    | if .drivers then
        "**Deploy `\(.host)` with `--boot`, then reboot it.** An out-of-tree driver moves "
        + "(\(.drivers_from | join(", ")) → \(.drivers_to | join(", "))) and `switch` fails activation against the loaded one. See *Applying this bump*."
      elif .series then
        "**`\(.host)` moves to a new kernel series: \(.kernel_from) → \(.kernel_to).** `switch` installs it; it runs, and anything that needs it works, only after a reboot."
      else empty end' "$rep/reboot.json")
else
  blind+=("How the bump has to be applied was not worked out (no kernel and driver comparison in this run).")
fi

# -------------------------------------------------------------- containers
bumped='[]'
if has "$sig/containers.json"; then
  # The images this pull request actually moves: the applied list when the
  # update job wrote one, every image the scan marked otherwise.
  if has "$rep/containers-applied.json"; then
    bumped=$(jq -c --slurpfile a "$rep/containers-applied.json" \
      '[ .[] | select(.state == "changed") | select(.name as $n | any($a[0][]; .name == $n and .outcome == "bumped")) ]' \
      "$sig/containers.json")
    into act < <(jq -r '.[] | select(.outcome != "bumped")
      | "**`\(.name)` was not bumped** (\(.from) → \(.to)): \(.outcome), \(.reason)."' "$rep/containers-applied.json")
  else
    bumped=$(jq -c '[ .[] | select(.state == "changed") ]' "$sig/containers.json")
  fi

  into act < <(jq -r '.[] | select((.required // []) | length > 0)
    | "**`\(.name)` \(.current) → \(.target): upstream marks \(.required | length) section(s) as needing action.** "
      + "Quoted under *Containers*; check each against what this repository sets for the service."' <<<"$bumped")

  if has "$sig/containers-verdict.json"; then
    into act < <(jq -r --argjson b "$bumped" '
      .containers[]?
      | select(.name as $n | any($b[]; .name == $n))
      | select((.before_deploying // "" | gsub("^\\s+|\\s+$"; "")) as $t
               | $t != "" and ($t | test("^Nothing beyond the deploy\\.?$") | not))
      | "**`\(.name)`: there is a step to take on the host before this deploys.** "
        + "It is the model'"'"'s reading, under *Before deploying* in *Containers*; merging deploys, so it comes first."' \
      "$sig/containers-verdict.json")
    if [ "$(jq 'length' <<<"$bumped")" -gt 0 ] && [ "$(jq -r '.degraded // false' "$sig/containers-verdict.json")" = "true" ]; then
      blind+=("The container model did not answer: no notes on what to watch for or do before deploying. Only the tables and the sections upstream marks are in this body.")
    fi
  fi

  into blind < <(jq -r '.[] | select(.state == "unknown")
    | "`\(.name)` could not be checked for a newer tag" + (if (.note // "") != "" then ": \(.note)" else "" end) + "."' "$sig/containers.json")
  into blind < <(jq -r '.[] | (.gaps // {}) as $g | .name as $n
    | (if $g.no_source then "`\($n)`: the image names no GitHub repository, so no release notes or issues were read for the bump." else empty end),
      (if $g.no_releases then "`\($n)`: no GitHub release maps to the tags it steps through; the bump was taken without notes." else empty end),
      (if ($g.empty // [] | length) > 0 then "`\($n)`: \($g.empty | length) release(s) in the window have no notes at all (\($g.empty | join(", ")))." else empty end),
      (if ($g.unshown // [] | length) > 0 then "`\($n)`: the window is longer than the model is shown; it read no notes for \($g.unshown | join(", "))." else empty end),
      (if ($g.marker_missing // [] | length) > 0 then "`\($n)`: its `notes-start` hint no longer matches upstream'"'"'s release notes; fix it in `\(.file)`." else empty end)' <<<"$bumped")
elif [ -d "$sig" ]; then
  blind+=("The pinned container images were not checked for newer tags.")
fi

# ------------------------------------------------------------------- holds
if has "$sig/verdict.json"; then
  into act < <(jq -r '.holds[]? | "**`\(.name)` is held at its current revision:** \(.reason)"' "$sig/verdict.json")
  if [ "$(jq -r '.degraded // false' "$sig/verdict.json")" = "true" ]; then
    blind+=("The triage model did not judge this bump ($(jq -r '.summary // "no reason recorded"' "$sig/verdict.json" | head -1)); nothing was considered for a hold. The builds still ran.")
  fi
else
  blind+=("There is no triage verdict for this bump.")
fi
if has "$sig/containers-verdict.json"; then
  into act < <(jq -r '.holds[]? | "**`\(.name)` is held at its current tag:** \(.reason)"' "$sig/containers-verdict.json")
fi
if has "$rep/late-holds.json"; then
  into act < <(jq -r '.[]? | "**`\(.name)` was held back after the build failed:** \(.reason)"' "$rep/late-holds.json")
fi
if has "$rep/hold-report.md"; then
  act+=("**A source is still held from an earlier week.** See *Held inputs*.")
fi
if has "$rep/fix-notes.md"; then
  act+=("**The fix agent changed this tree to make it build.** Read *What the fix agent did*, then the diff outside the lock files.")
fi

# ------------------------------------------------------------- workarounds
if has "$rep/workarounds.json"; then
  into act < <(jq -r '.[]
    | if .state == "resolved" and .action != "retired" then
        "**Workaround `\(.id)` is fixed upstream and still in the tree** ("
        + (if .action == "retire-blocked" then "its removal was blocked by an unrelated failure"
           elif .action == "retire-failed" then "its automatic removal failed"
           else "it is removed by hand" end)
        + "). See *Workarounds*."
      elif .state == "added" then
        "**Workaround `\(.id)` was added in this run** by the fix agent. See *Workarounds*."
      else empty end' "$rep/workarounds.json")
  into blind < <(jq -r '.[] | select(.state == "unknown")
    | "Workaround `\(.id)`: the probe for its upstream fix did not answer (\(.detail))."' "$rep/workarounds.json")
elif [ -d "$rep" ]; then
  blind+=("The workaround register was not checked against upstream.")
fi

# ----------------------------------------------------------------- staging
if has "$rep/staging-report/result.json"; then
  into act < <(jq -r '.skipped[]? | "**`\(.)` did not merge cleanly and is not in this pull request.** It needs its own."' \
    "$rep/staging-report/result.json")
fi

# ------------------------------------------------- what else went unchecked
if has "$sig/digest.md"; then
  unread=$(awk '/^## / { name = substr($0, 4) } /^- new commits upstream: \?$/ { printf "%s`%s`", sep, name; sep = ", " }' "$sig/digest.md")
  [ -z "$unread" ] || blind+=("Upstream could not be read for $unread, so the triage saw nothing about what the bump takes from them.")
fi
if has "$sig/packages.json"; then
  into blind < <(jq -r '.[] | select(.state == "unknown" or .state == "unsupported-forge")
    | "Watched package `\(.attr)` was not read ("
      + (if .state == "unknown" then "its version did not evaluate" else "its forge is not implemented" end) + ")."' "$sig/packages.json")
fi
if has "$sig/verdict.json" && ! has "$sig/release-notes.md" \
   && [ "$(jq -r '.degraded // false' "$sig/verdict.json")" != "true" ]; then
  blind+=("The overview of what landed upstream was not written this week.")
fi
if has "$rep/package-summary.json"; then
  into blind < <(jq -r 'select((.uncompared // []) | length > 0)
    | "Package versions were not compared for \(.uncompared | map("`" + . + "`") | join(", ")): it did not evaluate on one side of the bump."' \
    "$rep/package-summary.json")
elif [ -d "$rep" ]; then
  blind+=("The table of package versions this bump changes could not be produced.")
fi
if has "$rep/unreachable-pins.txt"; then
  # shellcheck disable=SC2016
  blind+=("These pins could not be reached and keep their revision: $(sed 's/.*/`&`/' "$rep/unreachable-pins.txt" | paste -sd, | sed 's/,/, /g').")
fi
if has "$rep/smoke-status.txt"; then
  case "$(cat "$rep/smoke-status.txt")" in
    0) ;;
    3) blind+=("opencode sent its smoke-test request and the model did not reply in time, so the fix agent's reply path is unverified this week.") ;;
    *) blind+=("opencode failed its smoke test: had the build broken, no fix agent would have run.") ;;
  esac
fi
case "${CACHED:-}" in
  "" | success) ;;
  *) act+=("**The cache push did not succeed ($CACHED).** Hosts will build this closure themselves when they switch.") ;;
esac

for f in "${!invalid[@]}"; do
  blind+=("\`$f\` from this run is not valid JSON, so whatever it records is missing above.")
done

# ------------------------------------------------------------------ render
echo "## Before you merge"
echo ""
if [ ${#act[@]} -eq 0 ] && [ ${#blind[@]} -eq 0 ]; then
  echo "Nothing was raised, and every source of evidence answered."
  echo ""
  echo "Checked: out-of-tree driver versions and the kernel series on every host;"
  echo "release-note sections upstream marks as needing action, and steps to"
  echo "take before deploying, for each bumped image; holds, from this week and"
  echo "earlier; workarounds fixed upstream; staged branches left out; and"
  echo "whether each collector and each model call returned."
  echo ""
else
  if [ ${#act[@]} -gt 0 ]; then
    echo "### Needs you"
    echo ""
    printf -- '- %s\n' "${act[@]}"
    echo ""
    [ ${#blind[@]} -gt 0 ] || { echo "Every source of evidence answered this week."; echo ""; }
  else
    echo "Nothing was raised by the checks that ran."
    echo ""
  fi
  if [ ${#blind[@]} -gt 0 ]; then
    echo "### Not checked this week"
    echo ""
    echo "Unknown, not known to be wrong: what a check could not see."
    echo ""
    printf -- '- %s\n' "${blind[@]}"
    echo ""
  fi
fi
if [ "$(jq 'length' <<<"$bumped")" -gt 0 ]; then
  echo "No check here starts a container: a bumped image first runs when the merge deploys it."
fi
