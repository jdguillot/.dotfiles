#!/usr/bin/env bash
# The gate: flake check, then build every host and every standalone home
# configuration, appending everything to build-failure.log so the fix agent
# has one file to read. Writes the lists to build-hosts.json and
# build-homes.json, and each result to path/<host> or path/home-<name>.
#
# Sequential rather than a job matrix, because the agent step that runs on
# failure needs the failing tree and the failing log in the same workspace,
# and a matrix job cannot hand its working tree to the next job.
#
# The host list is derived here rather than passed in: when the bump breaks
# evaluation there is no list to pass, and this script is the thing that has
# to report that.
#
# Order matters. `nix flake check` runs last, not first, because evaluating a
# flake output can need a store path realised (hermes-agent is uv2nix, which
# is import-from-derivation throughout) and `--no-build` refuses to realise
# it -- the check then fails with `path '...' is not valid` for a path that
# has nothing to do with the bump, and passes on a re-run once the builds
# have populated the store. Cheap `nix eval` of the two lists stays up front
# as the fail-fast gate; a genuinely broken evaluation also fails the
# per-host build below, with a better message than the check gives.
set -euo pipefail

: > build-failure.log
mkdir -p path

nix eval .#nixosConfigurations --apply builtins.attrNames --json > build-hosts.json
nix eval .#homeConfigurations --apply builtins.attrNames --json > build-homes.json

failed=()
while read -r h; do
  echo "::group::build $h"
  # --no-link: the toplevel is kept alive by the printed path being pushed
  # to the caches in the next job, not by a result symlink in a workspace
  # that is deleted when the ephemeral runner is torn down.
  if nix build --fallback --no-link --print-out-paths \
       ".#nixosConfigurations.$h.config.system.build.toplevel" \
       > "path/$h" 2>> build-failure.log; then
    echo "built $h -> $(cat "path/$h")"
  else
    rm -f "path/$h"
    failed+=("$h")
    echo "::error::$h failed to build"
  fi
  echo "::endgroup::"
done < <(tr -d '[]" ' < build-hosts.json | tr ',' '\n' | grep .)

# The standalone `home-manager switch` targets. The host builds cover home
# only where it is a NixOS module; these are the ones a bump can break with
# nothing else noticing, and their closures are worth caching too.
while read -r hc; do
  echo "::group::build home $hc"
  # The attribute name carries a `@`, so the attrpath needs quoting.
  if nix build --fallback --no-link --print-out-paths \
       ".#homeConfigurations.\"$hc\".activationPackage" \
       > "path/home-$hc" 2>> build-failure.log; then
    echo "built home $hc -> $(cat "path/home-$hc")"
  else
    rm -f "path/home-$hc"
    failed+=("home:$hc")
    echo "::error::home $hc failed to build"
  fi
  echo "::endgroup::"
done < <(tr -d '[]" ' < build-homes.json | tr ',' '\n' | grep .)

# Every target, not just the first: one run should surface every breakage the
# bump caused, so the agent can fix them together.
if [ ${#failed[@]} -gt 0 ]; then
  echo "failed to build: ${failed[*]}" | tee -a build-failure.log
  exit 1
fi

# Both cheap now that every toplevel they depend on is built, and the store
# holds whatever evaluation needs realised.
#
# --show-trace on the check only. A failing `nix build` already names the
# offending file and line, and the trace adds ~800 lines of nixpkgs-internal
# frames that would crowd the fix agent's log budget. `nix flake check` is the
# opposite: it truncates its own trace by default and says so, and its errors
# reach you through a module chain the untraced output never names.
#
# --no-build still: deploy-rs's activation check depends on every node's
# profile path, and those are built explicitly below rather than as a side
# effect of the check.
echo "::group::nix flake check"
nix flake check --no-build --show-trace 2>&1 | tee -a build-failure.log
echo "::endgroup::"

# Catches a deploy.nodes change that a bump broke without breaking any host.
echo "::group::deploy-rs checks"
nix build --no-link --print-out-paths \
  .#checks.x86_64-linux.deploy-schema \
  .#checks.x86_64-linux.deploy-activate 2>&1 | tee -a build-failure.log
echo "::endgroup::"
