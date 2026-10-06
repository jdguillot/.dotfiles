#!/usr/bin/env bash
# Upstream signal for the container images this repo pins: every `image:`
# line in a tracked compose file under modules/ or hosts/. Nothing else. A
# container a host runs outside this tree is not this repo's to move, and
# the images inside odysseus's pinned source tree move when that npins pin
# does.
#
# collect-upstream-signal.sh watches what the lock files pin, and an image
# tag is in neither lock file: a compose file keeps the tag it was written
# with, so until now these services moved only when somebody remembered.
#
# There is no list to maintain. The compose files are the inventory, and
# everything else is derived: the tags a bump may take come from the shape
# of the current tag (first number fixed, the rest free, so `v3.7` may
# become `v3.8` but never `v4.0`); the project whose release notes to read
# comes from the image's own `org.opencontainers.image.source` label; the
# files the model is shown are the ones next to the compose file. The
# exceptions are declared where they apply, as a `# bump:` comment on the
# line above the image (see hint_get below for the keys).
#
# Per image: the tag the tree has, every tag the registry has that fits,
# the newest of those that has been out long enough to trust
# (MIN_AGE_DAYS), and for a GitHub project the release notes between the
# two tags plus what people have filed since the current release. The
# registry is read with plain curl against the OCI distribution API and an
# anonymous pull token -- what `docker pull` sees, and no new tool on the
# runner's PATH.
#
# Advisory and deterministic, like the rest of the scan. The model reads the
# digest and says what to hold; apply-container-updates.sh edits the files;
# the person reading the pull request is the gate. There is no build that
# fails on a wrong image tag -- only a container that does not come up on
# the host after the merge -- which is why the digest carries this repo's
# own config files for each image: a removed config key is visible there.
#
# Writes into $OUT_DIR (default: upstream-signal):
#   containers.json         per image: state, current and target tag, counts
#   digest-containers.md    the evidence the model reads
#   containers.md           the compact table for the summary and the PR
set -uo pipefail

OUT_DIR="${OUT_DIR:-upstream-signal}"
# A tag younger than this is skipped for the next older one that fits. A
# release that is on fire is usually found out within days, and the bump
# that would have taken it is only a week away anyway. 0 disables it; a
# `min-age=` hint overrides it per image.
MIN_AGE_DAYS="${CONTAINER_MIN_AGE_DAYS:-3}"
RELEASE_FETCH="${CONTAINER_RELEASE_FETCH:-100}"
RELEASE_SHOW="${CONTAINER_RELEASE_SHOW:-15}"
RELEASE_BODY_CAP="${CONTAINER_RELEASE_BODY_CAP:-5000}"
ISSUE_SHOW="${CONTAINER_ISSUE_SHOW:-15}"
LOUD_SHOW="${CONTAINER_LOUD_SHOW:-10}"
FALLBACK_DAYS="${CONTAINER_FALLBACK_DAYS:-21}"
CONTEXT_CAP="${CONTAINER_CONTEXT_CAP:-12000}"
TAG_PAGES="${CONTAINER_TAG_PAGES:-50}"

mkdir -p "$OUT_DIR"
digest="$OUT_DIR/digest-containers.md"
out="$OUT_DIR/containers.json"
table="$OUT_DIR/containers.md"

echo '[]' > "$out"
: > "$digest"
: > "$table"

# A tag's version is the run of numbers in it, so `v3.7` < `v3.10`, and
# `14-vectorchord0.4.3-pgvectors0.2.0` compares part by part. The pattern
# is what keeps every candidate in one shape.
KEY='def key: [scan("[0-9]+") | tonumber];'

# The inventory: every image line in every tracked compose file, with the
# compose service it belongs to and the `# bump:` hint above it, if any.
# One record per line: file, line number, service, image reference, hint.
inventory() {
  git ls-files 'modules/**/compose*.yaml' 'modules/**/compose*.yml' 'hosts/**/compose*.yaml' 'hosts/**/compose*.yml' \
    | while IFS= read -r f; do
        awk -v file="$f" '
          /^services:/ { insvc = 1; next }
          insvc && /^[^ #]/ { insvc = 0 }
          insvc && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { svc = $1; sub(/:$/, "", svc) }
          insvc && /^[[:space:]]*image:/ {
            ref = $2; gsub(/["'\'']/, "", ref)
            hint = ""
            if (prev ~ /^[[:space:]]*#[[:space:]]*bump:/) { hint = prev; sub(/^[[:space:]]*#[[:space:]]*bump:[[:space:]]*/, "", hint) }
            else if ($0 ~ /#[[:space:]]*bump:/) { hint = $0; sub(/^.*#[[:space:]]*bump:[[:space:]]*/, "", hint) }
            printf "%s\t%d\t%s\t%s\t%s\n", file, NR, svc, ref, hint
          }
          { prev = $0 }' "$f"
      done
}

# `# bump: key=value key="value with spaces"` on the line above an image.
# Keys:
#   follows=<image>        this tag is whatever upstream's compose names
#   source=<path>          beside the followed image's release; the path
#   service=<name>         and service in the followed project's repository
#   pattern=<regex>        the tags a bump may take, instead of the derived one
#   repo=github:owner/repo the project to read, instead of the image's label
#   notes-start=<text>     drop release-note text before this (a preamble)
#   context=<path,...>     extra files to show the model
#   min-age=<days>         this image's own MIN_AGE_DAYS
#   skip                   never bump or report this image
hint_get() {
  local hint="$1" k="$2" v
  v=$(grep -oE "(^|[[:space:]])$k=(\"[^\"]*\"|[^[:space:]]+)" <<<"$hint" | head -1 | sed -E "s/^[[:space:]]*$k=//; s/^\"//; s/\"\$//")
  printf '%s\n' "$v"
}
hint_has() { grep -qE "(^|[[:space:]])$2([[:space:]]|$)" <<<"$1"; }

# The tags a bump may take, from the current tag's own shape: the first
# number stays, every later one is free, the text is literal. `v1.99.0`
# gives ^v1\.[0-9]+\.[0-9]+$; `17-alpine` gives ^17-alpine$, which only it
# matches -- a moving alias, left alone. `@` is safe as a marker because a
# registry tag cannot contain one.
derive_pattern() {
  local tag="$1" esc first
  esc=$(printf '%s' "$tag" | sed 's/[][\.*^$+?(){}|/]/\\&/g')
  first=$(grep -oE '[0-9]+' <<<"$tag" | head -1)
  if [ -n "$first" ]; then
    esc=$(sed -E 's/[0-9]+/@/g' <<<"$esc")
    esc="${esc/@/$first}"
    esc="${esc//@/[0-9]+}"
  fi
  printf '^%s$' "$esc"
}

# Registry host and repository path for an image reference, by docker's own
# rule: the first component is a registry only if it has a dot or a colon
# or is `localhost`. Official images live under library/, and docker.io is
# the registry's public name, not its API host.
split_image() {
  local image="$1" first host path
  first="${image%%/*}"
  if [ "$first" != "$image" ] && { [[ "$first" == *.* ]] || [[ "$first" == *:* ]] || [ "$first" = localhost ]; }; then
    host="$first"
    path="${image#*/}"
  else
    host="docker.io"
    path="$image"
    [[ "$path" == */* ]] || path="library/$path"
  fi
  case "$host" in docker.io | index.docker.io) host="registry-1.docker.io" ;; esac
  echo "$host $path"
}

# Anonymous pull token, from the challenge the registry sends back. Realm
# and service differ per registry and the challenge is the one place every
# registry states them.
registry_token() {
  local host="$1" path="$2" hdr realm service scope
  hdr=$(curl -sS -o /dev/null -D - --max-time 30 "https://$host/v2/$path/tags/list" \
    | tr -d '\r' | grep -i '^www-authenticate:' || true)
  [ -n "$hdr" ] || return 0
  realm=$(sed -n 's/.*realm="\([^"]*\)".*/\1/p' <<<"$hdr")
  service=$(sed -n 's/.*service="\([^"]*\)".*/\1/p' <<<"$hdr")
  scope=$(sed -n 's/.*scope="\([^"]*\)".*/\1/p' <<<"$hdr")
  [ -n "$scope" ] || scope="repository:$path:pull"
  curl -fsS --max-time 30 -G "$realm" --data-urlencode "service=$service" --data-urlencode "scope=$scope" \
    | jq -r '.token // .access_token // empty'
}

# Every tag, following `Link: rel="next"` -- ghcr pages, Docker Hub does
# not. `auth` is the bearer header for the image being read. ghcr rate
# limits anonymous listing (a 429 on back-to-back runs), so the registry
# calls retry with backoff rather than report a registry that did answer
# as one that did not.
RETRY=(--retry 4 --retry-delay 3 --retry-all-errors)
auth=()
registry_tags() {
  local host="$1" path="$2"
  local url="https://$host/v2/$path/tags/list?n=1000" n=0 next hdrs
  hdrs=$(mktemp)
  while [ -n "$url" ] && [ "$n" -lt "$TAG_PAGES" ]; do
    n=$((n + 1))
    curl -fsS --max-time 60 "${RETRY[@]}" -D "$hdrs" "${auth[@]}" "$url" | jq -r '.tags[]?' || { rm -f "$hdrs"; return 1; }
    next=$(tr -d '\r' < "$hdrs" | grep -i '^link:' | sed -n 's/.*<\([^>]*\)>.*rel="next".*/\1/p')
    [ -n "$next" ] || break
    case "$next" in /*) url="https://$host$next" ;; *) url="$next" ;; esac
  done
  rm -f "$hdrs"
}

# What is behind a tag: the platforms it has images for, and the source
# repository its config names. A tag that exists but has no linux/amd64
# image pulls fine as far as the registry is concerned and fails on the
# host, which is the one thing about a bump nothing here can build; the
# label is where the release notes live. Prints "<platforms>\t<source>".
ACCEPT='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
inspect_tag() {
  local host="$1" path="$2" tag="$3" m platforms="unknown" d cfg blob source=""
  m=$(curl -fsS --max-time 60 "${RETRY[@]}" "${auth[@]}" -H "Accept: $ACCEPT" "https://$host/v2/$path/manifests/$tag") \
    || { printf 'unknown\t\n'; return; }
  if jq -e '.manifests' >/dev/null 2>&1 <<<"$m"; then
    # Attestation entries carry os "unknown"; they are not images.
    platforms=$(jq -r '[.manifests[] | select(.platform.os != "unknown") | "\(.platform.os)/\(.platform.architecture)"] | unique | join(" ")' <<<"$m")
    d=$(jq -r '[.manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64")][0].digest // empty' <<<"$m")
    [ -n "$d" ] && m=$(curl -fsS --max-time 60 "${RETRY[@]}" "${auth[@]}" -H "Accept: $ACCEPT" "https://$host/v2/$path/manifests/$d" 2>/dev/null || echo '{}')
  fi
  cfg=$(jq -r '.config.digest // empty' <<<"$m")
  if [ -n "$cfg" ]; then
    blob=$(curl -fsSL --max-time 60 "${RETRY[@]}" "${auth[@]}" "https://$host/v2/$path/blobs/$cfg" 2>/dev/null || echo '{}')
    [ "$platforms" != unknown ] || platforms=$(jq -r '"\(.os // "?")/\(.architecture // "?")"' <<<"$blob")
    source=$(jq -r '.config.Labels["org.opencontainers.image.source"] // empty' <<<"$blob")
  fi
  printf '%s\t%s\n' "$platforms" "$source"
}

# Which host runs each compose project, so the digest can say "traefik on
# thkpd-pve1 and ryzn-server" instead of leaving the model and the reader to
# guess. One evaluation over every host; unknown if it fails. A compose file
# belongs to the projects named after its directory (`immich/` is `immich`
# and `immich-ml`).
echo "::group::which hosts run which compose projects"
hosts_json=$(nix eval --json .#nixosConfigurations \
  --apply 'cs: builtins.mapAttrs (_: c: builtins.attrNames c.config.cyberfighter.features.compose.projects) cs' \
  2>/dev/null || echo '{}')
echo "$hosts_json"
echo "::endgroup::"
projects_for() {
  jq -r --arg b "$1" '[.[][] | select(. == $b or startswith($b + "-"))] | unique | join(", ")' <<<"$hosts_json"
}
hosts_for() {
  jq -r --arg b "$1" '
    to_entries | map(select(.value | any(. == $b or startswith($b + "-")))) | map(.key) | join(", ")' <<<"$hosts_json"
}

# A fenced copy of a file for the model: this repo's config for the image,
# where a removed or renamed key would be set. Capped; the tail of a long
# file is the least likely place for one.
context_block() {
  local f="$1" lang
  [ -s "$f" ] || return 0
  case "$f" in *.nix) lang=nix ;; *.toml) lang=toml ;; *.yaml | *.yml) lang=yaml ;; *.json) lang=json ;; *) lang="" ;; esac
  echo "#### \`$f\`"
  echo ""
  echo "\`\`\`$lang"
  if [ "$(wc -c < "$f")" -gt "$CONTEXT_CAP" ]; then
    head -c "$CONTEXT_CAP" "$f"
    printf '\n[... trimmed at %s bytes ...]\n' "$CONTEXT_CAP"
  else
    cat "$f"
  fi
  echo "\`\`\`"
  echo ""
}

{
  echo "# Container images this repo pins"
  echo ""
  echo "Every \`image:\` line in the compose files under modules/ and hosts/."
  echo "The tag in the file is the pin: there is no lock file, it is what the"
  echo "host pulls after a deploy. Nothing builds against an image tag, so a"
  echo "bad one fails on the host, not in CI."
  echo ""
} >> "$digest"

results='[]'
while IFS=$'\t' read -r file lineno service ref hint; do
  [ -n "$ref" ] || continue
  image="${ref%:*}"
  tag="${ref##*:}"
  [ "$image" != "$ref" ] || { image="$ref"; tag="latest"; }
  dir=$(basename "$(dirname "$file")")
  name="$dir/$service"
  projects=$(projects_for "$dir")
  hosts=$(hosts_for "$dir")
  echo "::group::$name ($ref)"

  rec=$(jq -n --arg n "$name" --arg i "$image" --arg f "$file" --argjson l "$lineno" --arg s "$service" \
    --arg p "$projects" --arg h "$hosts" --arg c "$tag" --arg hint "$hint" \
    '{ name: $n, image: $i, file: $f, lineno: $l, service: $s, line: "image: @IMAGE@:@TAG@",
       projects: $p, hosts: $h, hint: $hint, track: "tags", slug: "", follows: "",
       state: "unknown", current: $c, target: null, note: "" }')

  {
    echo "## $name"
    echo ""
    echo "- image: \`$image\`, pinned in \`$file\` line $lineno (compose service \`$service\`)"
    echo "- compose project(s): ${projects:-none found}; runs on: ${hosts:-no host in this tree}"
    [ -z "$hint" ] || echo "- declared: \`# bump: $hint\`"
  } >> "$digest"

  if hint_has "$hint" skip; then
    rec=$(jq '.track = "skipped" | .state = "skipped" | .note = "skip hint"' <<<"$rec")
    echo "- **skipped** by its hint." >> "$digest"
    echo "" >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  # A placeholder tag is rendered by the module from another pin (the ML
  # image's tag is the immich release plus a suffix). Nothing to read;
  # listed so the model knows it moves too.
  if [[ "$tag" == @*@ ]]; then
    rec=$(jq --arg t "$tag" '.track = "derived" | .state = "derived" | .current = null | .note = ("rendered by the module from " + $t)' <<<"$rec")
    echo "- derived: the tag is \`$tag\`, rendered by the module from another pin, so it moves with that" >> "$digest"
    echo "" >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  read -r host path <<<"$(split_image "$image")"
  token=$(registry_token "$host" "$path" 2>/dev/null || true)
  auth=()
  [ -n "$token" ] && auth=(-H "Authorization: Bearer $token")

  # The project to read. The image's own label first, a `repo=` hint over
  # it; a label that is not GitHub (a base image's, say) is named and not
  # read, which beats an empty section that reads as "nothing was filed".
  IFS=$'\t' read -r cur_platforms source <<<"$(inspect_tag "$host" "$path" "$tag")"
  repo=$(hint_get "$hint" repo)
  slug=""
  if [ -n "$repo" ]; then
    case "$repo" in github:*) slug="${repo#github:}" ;; *) echo "container-signal: $name: repo hint '$repo' is not github:, not read" >&2 ;; esac
  elif [[ "$source" == https://github.com/* ]]; then
    slug=$(sed -E 's#https://github\.com/([^/]+/[^/#?]+).*#\1#; s/\.git$//' <<<"$source")
  fi
  rec=$(jq --arg s "$slug" --arg src "$source" '.slug = $s | .source = $src' <<<"$rec")
  {
    echo "- pinned: **$tag** (platforms: $cur_platforms)"
    if [ -n "$slug" ]; then echo "- release notes and issues read from \`github:$slug\`$([ -n "$repo" ] && echo ' (hint)' || echo " (the image's source label)")"
    elif [ -n "$source" ]; then echo "- source label \`$source\` is not a GitHub repository; no release notes read (a \`repo=\` hint would name one)"
    else echo "- no source label on the image; no release notes read (a \`repo=\` hint would name a repository)"; fi
  } >> "$digest"

  follows=$(hint_get "$hint" follows)
  if [ -n "$follows" ]; then
    # The tag upstream's own compose file names beside the release the
    # followed image is moving to. For Immich's Postgres build that is the
    # only right answer: the server checks the extension versions it finds
    # at start, and the registry's newest is not what it was released with.
    src_path=$(hint_get "$hint" source)
    src_service=$(hint_get "$hint" service)
    f_rec=$(jq -c --arg i "$follows" '[.[] | select(.image == $i)] | first // empty' <<<"$results")
    f_target=$(jq -r '.target // .current // empty' <<<"$f_rec")
    f_slug=$(jq -r '.slug // empty' <<<"$f_rec")
    [ -n "$slug" ] && [ -n "$repo" ] && f_slug="$slug"
    rec=$(jq --arg f "$follows" '.track = "upstream-compose" | .follows = $f' <<<"$rec")
    echo "- follows \`$follows\` ($(jq -r '.state // "not found above"' <<<"$f_rec"), ${f_target:-?}): takes the tag \`$f_slug/${src_path:-?}\` names for service \`${src_service:-?}\` at that release" >> "$digest"
    if [ -z "$f_target" ] || [ -z "$f_slug" ] || [ -z "$src_path" ] || [ -z "$src_service" ]; then
      rec=$(jq '.state = "unknown" | .note = "follows an image not resolved above it, or the hint lacks source=/service="' <<<"$rec")
      echo "- **not resolved**: the followed image has to be listed above this one in the same file, with a GitHub repository, and the hint needs \`source=\` and \`service=\`." >> "$digest"
    else
      compose_text=$(gh api -H 'Accept: application/vnd.github.raw+json' \
        "repos/$f_slug/contents/$src_path?ref=$f_target" 2>/dev/null || true)
      # The service's first `image:` line, digest stripped: the tag is the
      # pin here and a digest would not match the file's form.
      wanted=$(awk -v s="  $src_service:" '
        $0 == s { f = 1; next }
        f && /^  [^ ]/ { f = 0 }
        f && /^ +image:/ { print $2; exit }' <<<"$compose_text")
      wanted="${wanted%%@*}"
      if [ -z "$wanted" ]; then
        rec=$(jq --arg p "$src_path" --arg t "$f_target" '.state = "unknown" | .note = ("no image for the service in " + $p + " at " + $t)' <<<"$rec")
        echo "- **not resolved**: no \`image:\` under \`$src_service\` in \`$f_slug/$src_path\` at \`$f_target\`." >> "$digest"
      elif [ "${wanted%:*}" != "$image" ]; then
        rec=$(jq --arg w "$wanted" '.state = "unknown" | .note = ("upstream now names a different image: " + $w)' <<<"$rec")
        echo "- **upstream names a different image at \`$f_target\`**: \`$wanted\`. The compose file needs a hand edit." >> "$digest"
      else
        wanted="${wanted##*:}"
        if [ "$wanted" = "$tag" ]; then
          rec=$(jq '.state = "unchanged"' <<<"$rec")
          echo "- upstream's compose at \`$f_target\` names the same tag. _No change this week._" >> "$digest"
        else
          IFS=$'\t' read -r platforms _ <<<"$(inspect_tag "$host" "$path" "$wanted")"
          ok=true
          [ "$platforms" = unknown ] || grep -qw 'linux/amd64' <<<"$platforms" || ok=false
          rec=$(jq --arg w "$wanted" --arg pl "$platforms" --argjson ok "$ok" \
            '.state = "changed" | .target = $w | .platforms = $pl | .platform_ok = $ok' <<<"$rec")
          {
            echo "- bump this week: **$tag -> $wanted**, as \`$f_slug/$src_path\` at \`$f_target\` names it"
            echo "- platforms behind the target: $platforms$([ "$ok" = true ] || echo ' -- **no linux/amd64 image; the bump is withheld**')"
          } >> "$digest"
        fi
      fi
    fi
    echo "" >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  pattern=$(hint_get "$hint" pattern)
  [ -n "$pattern" ] || pattern=$(derive_pattern "$tag")
  rec=$(jq --arg p "$pattern" '.pattern = $p' <<<"$rec")
  if [[ "$pattern" != *'[0-9]+'* ]]; then
    # Only the tag itself can match: a moving alias. The file does not
    # change; the host takes the newer build on its next
    # `<project>-compose pull`.
    rec=$(jq '.track = "floating" | .state = "floating"' <<<"$rec")
    {
      echo "- a moving alias (no version to step): not bumped by this script; the host refreshes it with \`${projects%%,*}-compose pull\`"
      echo ""
    } >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  all_tags=$(registry_tags "$host" "$path") || all_tags=""
  if [ -z "$all_tags" ]; then
    rec=$(jq '.state = "unknown" | .note = "the registry did not answer"' <<<"$rec")
    echo "- **registry unreachable**: \`$host\` returned no tags for \`$path\`." >> "$digest"
    echo "" >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi
  candidates=$(jq -R -s --arg p "$pattern" "$KEY"'
    split("\n") | map(select(length > 0 and test($p))) | unique | sort_by(key) | reverse' <<<"$all_tags")
  newest=$(jq -r '.[0] // empty' <<<"$candidates")
  echo "pinned $tag; $(jq 'length' <<<"$candidates") tag(s) match $pattern, newest ${newest:-none}"

  releases='[]'
  [ -z "$slug" ] || releases=$(gh api "repos/$slug/releases?per_page=$RELEASE_FETCH" 2>/dev/null || echo '[]')
  K=$(jq -n --arg c "$tag" "$KEY"'$c | key | length')
  min_age=$(hint_get "$hint" min-age)
  [ -n "$min_age" ] || min_age="$MIN_AGE_DAYS"

  # Newest first; the first candidate that is newer than the pin and old
  # enough wins. Age comes from the earliest stable release on that line
  # -- v3.8.0 for a `v3.8` tag -- and a candidate no release maps to is
  # taken as is: an unknown age is not a young one.
  target=""
  target_published=""
  target_age=""
  young='[]'
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    newer=$(jq -n --arg c "$c" --arg cur "$tag" "$KEY"'($c | key) > ($cur | key)')
    [ "$newer" = true ] || break
    published=$(jq -r --arg c "$c" --argjson k "$K" "$KEY"'
      [ .[] | select((.draft | not) and (.prerelease | not))
            | select(((.tag_name | key)[0:$k]) == (($c | key)[0:$k]))
            | .published_at ] | sort | first // empty' <<<"$releases")
    age=""
    [ -z "$published" ] || age=$(( ( $(date -u +%s) - $(date -u -d "$published" +%s) ) / 86400 ))
    if [ -n "$age" ] && [ "$age" -lt "$min_age" ]; then
      young=$(jq -c --arg c "$c" --argjson a "$age" '. + [{ tag: $c, age: $a }]' <<<"$young")
      continue
    fi
    target="$c"
    target_published="$published"
    target_age="$age"
    break
  done < <(jq -r '.[]' <<<"$candidates")

  {
    echo "- tags a bump may take: \`$pattern\`$([ -n "$(hint_get "$hint" pattern)" ] && echo ' (hint)' || echo ' (derived from the pinned tag)'); newest matching: **${newest:-none}**"
    if [ "$(jq 'length' <<<"$young")" -gt 0 ]; then
      echo "- skipped as younger than $min_age day(s): $(jq -r 'map("\(.tag) (\(.age)d)") | join(", ")' <<<"$young")"
    fi
  } >> "$digest"

  if [ -z "$target" ]; then
    rec=$(jq --argjson y "$young" '.state = "unchanged" | .young = $y' <<<"$rec")
    echo "" >> "$digest"
    echo "_No bump this week._" >> "$digest"
    echo "" >> "$digest"
    results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
    echo "::endgroup::"
    continue
  fi

  IFS=$'\t' read -r platforms _ <<<"$(inspect_tag "$host" "$path" "$target")"
  ok=true
  [ "$platforms" = unknown ] || grep -qw 'linux/amd64' <<<"$platforms" || ok=false
  {
    echo "- bump this week: **$tag -> $target**$([ -n "$target_published" ] && echo " (released ${target_published:0:10}, $target_age day(s) ago)")"
    echo "- platforms behind the target: $platforms$([ "$ok" = true ] || echo ' -- **no linux/amd64 image; the bump is withheld**')"
    echo ""
  } >> "$digest"

  # The releases the bump steps through, notes included: the one document
  # that says what changed, and where "breaking" is written down when it
  # is. Ordered by version, so a backport to an older line does not land
  # between two releases of the line being taken.
  notes_start=$(hint_get "$hint" notes-start)
  window=$(jq -c --arg cur "$tag" --arg t "$target" --argjson k "$K" "$KEY"'
    [ .[] | select((.draft | not) and (.prerelease | not))
          | select(((.tag_name | key)[0:$k]) > (($cur | key)[0:$k]))
          | select(((.tag_name | key)[0:$k]) <= (($t | key)[0:$k])) ]
    | sort_by(.tag_name | key)' <<<"$releases")
  n_window=$(jq 'length' <<<"$window")
  if [ "$n_window" -gt 0 ]; then
    {
      echo "### releases stepped through ($n_window, oldest first)"
      echo ""
      if [ "$n_window" -gt "$RELEASE_SHOW" ]; then
        echo "_Notes shown for the newest $RELEASE_SHOW; the rest by name:_ $(jq -r --argjson n "$RELEASE_SHOW" '.[0:(length - $n)] | map(.tag_name) | join(", ")' <<<"$window")"
        echo ""
      fi
      # Body from `notes-start` on when the hint names one (a signing
      # preamble repeated on every release is not notes), headings pushed
      # below this digest's own, then the cap.
      jq -r --argjson n "$RELEASE_SHOW" --argjson cap "$RELEASE_BODY_CAP" --arg start "$notes_start" '
        def body:
          (.body // "")
          | (if $start == "" then . elif test($start) then .[match($start).offset:] else "" end)
          | split("\n") | map(if startswith("#") then "###" + . else . end) | join("\n")
          | gsub("^\\s+|\\s+$"; "");
        .[-($n):][] |
        "#### \(.tag_name) (\(.published_at[0:10]))\(if .name and .name != .tag_name then " -- " + .name else "" end)\n\n"
        + (body | if . == "" then "_No release notes._"
                  elif length > $cap then .[0:$cap] + "\n\n[... trimmed at \($cap) characters ...]"
                  else . end)
        + "\n"' <<<"$window"
      echo ""
    } >> "$digest"
  elif [ -n "$slug" ]; then
    echo "_No GitHub release maps to the tags between $tag and $target (the project may tag without releasing, or the window starts before the $RELEASE_FETCH releases read)._" >> "$digest"
    echo "" >> "$digest"
  fi

  n_issues=0
  n_loud=0
  if [ -n "$slug" ]; then
    since=$(jq -r --arg cur "$tag" --argjson k "$K" "$KEY"'
      [ .[] | select((.draft | not) and (.prerelease | not))
            | select(((.tag_name | key)[0:$k]) == (($cur | key)[0:$k]))
            | .published_at ] | sort | first // empty' <<<"$releases")
    [ -n "$since" ] || since=$(date -u -d "$FALLBACK_DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)

    # Loudest first, as collect-package-signal.sh does: many people on one
    # thread is what a release being on fire looks like.
    loud=$(gh api -X GET search/issues \
      -f q="repo:$slug created:>=${since%%T*}" \
      -f sort=comments -f order=desc -f per_page="$LOUD_SHOW" 2>/dev/null || echo '{}')
    if [ "$(jq '.items | length // 0' <<<"$loud")" -gt 0 ]; then
      {
        echo "### most discussed, filed since ${since%%T*}"
        echo ""
        jq -r '.items[] | "- [" + (if .pull_request then "PR" else "issue" end) + " " + .state + "] "
               + .title
               + " (" + (.comments | tostring) + " comments, "
               + (.reactions.total_count | tostring) + " reactions)"
               + " " + .html_url' <<<"$loud"
        echo ""
      } >> "$digest"
    fi
    n_loud=$(jq '[.items[]? | select(.comments >= 5)] | length' <<<"$loud")

    issues=$(gh api "repos/$slug/issues?state=all&sort=updated&direction=desc&per_page=$ISSUE_SHOW&since=$since" 2>/dev/null || echo '[]')
    n_issues=$(jq 'length' <<<"$issues")
    if [ "$n_issues" -gt 0 ]; then
      {
        echo "### most recently touched"
        echo ""
        jq -r '.[] | "- [" + (if .pull_request then "PR" else "issue" end) + " " + .state + "] "
               + .title
               + " (" + (.comments | tostring) + " comments)"
               + (if (.labels | length) > 0 then " (" + ([.labels[].name] | join(", ")) + ")" else "" end)
               + " " + .html_url' <<<"$issues"
        echo ""
      } >> "$digest"
    fi
  fi

  # What this repo sets for the image: the compose file, every tracked
  # config file beside it, and whatever a `context=` hint adds (a host's
  # own config file for the service, say).
  {
    echo "### this repository's files for it"
    echo ""
    context_block "$file"
    while IFS= read -r cf; do
      [ -n "$cf" ] && [ "$cf" != "$file" ] && context_block "$cf"
    done < <(git ls-files "$(dirname "$file")" | grep -E '\.(nix|toml|ya?ml|json|conf)$')
    while IFS= read -r cf; do
      [ -n "$cf" ] && context_block "$cf"
    done < <(hint_get "$hint" context | tr ',' '\n')
  } >> "$digest"

  rec=$(jq --arg t "$target" --arg pub "$target_published" --arg age "$target_age" \
    --arg pl "$platforms" --argjson ok "$ok" --argjson y "$young" \
    --argjson rel "$n_window" --argjson iss "$n_issues" --argjson loud "$n_loud" \
    '.state = "changed" | .target = $t | .platforms = $pl | .platform_ok = $ok | .young = $y
     | .release_date = (if $pub == "" then null else $pub[0:10] end)
     | .age_days = (if $age == "" then null else ($age | tonumber) end)
     | .releases = $rel | .issues = $iss | .busy_threads = $loud' <<<"$rec")
  results=$(jq --argjson r "$rec" '. + [$r]' <<<"$results")
  echo "::endgroup::"
done < <(inventory)

printf '%s\n' "$results" > "$out"

# The compact form, for the job summary and the pull request.
{
  echo "### Container images"
  echo ""
  echo "| Image | pinned in | pinned | this week | hosts |"
  echo "|---|---|---|---|---|"
  jq -r '.[]
    | "| `\(.image)` | `\(.name)` | \(.current // "—") | "
    + (if .state == "changed" then "**-> \(.target)**"
         + (if .release_date then " (\(.release_date))" else "" end)
         + (if .platform_ok == false then " ⚠ no linux/amd64" else "" end)
       elif .state == "unchanged" then "_unchanged_"
         + (if (.young // [] | length) > 0 then " (\(.young[0].tag) is \(.young[0].age)d old)" else "" end)
       elif .state == "floating" then "_floating alias_"
       elif .state == "derived" then "_\(.note)_"
       elif .state == "skipped" then "_skipped_"
       else "_\(.state)_" + (if .note != "" then ": \(.note)" else "" end) end)
    + " | \(if .hosts == "" then "—" else .hosts end) |"' "$out"
  echo ""
  if jq -e 'any(.[]; .state == "floating")' "$out" >/dev/null; then
    echo "A floating alias is a tag with no version to step: the file never changes"
    echo "and the host takes the newer build on its next \`<project>-compose pull\`."
    echo ""
  fi
} > "$table"

echo "Collected $(jq 'length' "$out") image(s): $(jq -r '[.[] | select(.state == "changed") | .name] | join(", ")' "$out") to bump; $(wc -c < "$digest") bytes of digest."
