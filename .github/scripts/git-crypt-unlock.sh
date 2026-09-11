#!/usr/bin/env bash
# Unlocks git-crypt in the job's checkout so builds see the secret files the
# way a host does. Locked, every sops path, activate script and toplevel CI
# caches differs from the one the host builds itself. public-paths.sh keeps
# the decrypted files off the public cachix.
#
# The key stays in .git for the rest of the job: git's clean filter needs it,
# and `git status` errors without it. The runner wipes its work dir on every
# (ephemeral) restart, so it does not outlive the job.
#
# Missing key (fork PRs get no secrets) or missing git-crypt (ryzn-server not
# rebuilt yet) falls back to a locked build with a warning: nothing leaks
# either way, the cache just misses.
set -euo pipefail

if [ -z "${GIT_CRYPT_KEY:-}" ]; then
  echo "::warning::GIT_CRYPT_KEY is not available to this run; building with git-crypt files locked"
  exit 0
fi
if ! command -v git-crypt >/dev/null 2>&1; then
  echo "::warning::git-crypt is not on the runner PATH; building locked. It comes from github-runner.extraPackages -- rebuild ryzn-server: deploy .#ryzn-server.system --remote-build"
  exit 0
fi

key=$(mktemp -p "${RUNNER_TEMP:-/tmp}")
trap 'rm -f "$key"' EXIT
base64 -d <<<"$GIT_CRYPT_KEY" > "$key"
git-crypt unlock "$key"
echo "git-crypt: unlocked"
