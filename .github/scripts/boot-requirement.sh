#!/usr/bin/env bash
# Works out which hosts this bump cannot fully apply with `switch` alone.
#
# Same comparison nixos-rebuild makes to decide whether a reboot is pending,
# only across the bump rather than against the running system: if `kernel`,
# `initrd` or the modules tree changes, switching installs the new userspace
# beside the old loaded kernel modules and the change does not take effect
# until reboot.
#
# The modules tree is the one that earns its place. It is built from
# boot.extraModulePackages as well as the kernel, so an out-of-tree driver
# bump -- nvidia being the one that matters here -- shows up even when the
# kernel itself is unchanged. That is the case where `switch` does not merely
# under-apply but actively breaks: new NVML userspace cannot initialise
# against the old loaded module, so nvidia-container-toolkit-cdi-generator
# fails and takes docker and everything behind it with it.
#
# Pure evaluation, no building.
#
# Usage:
#   boot-requirement.sh record  <out.json>
#   boot-requirement.sh compare <before.json> <after.json>   # markdown to stdout
set -euo pipefail

record() {
  local out="$1" host
  echo "{}" > "$out"
  while read -r host; do
    echo "::group::boot inputs for $host" >&2
    local k i m
    # WSL hosts boot the Windows kernel: boot.kernel.enable is false, so
    # system.build.kernel and initialRamdisk are never defined and evaluating
    # them is a hard error. No bump can require a reboot there, so record them
    # as unchanging and let compare() list them as switch-only.
    if [ "$(nix eval --json ".#nixosConfigurations.$host.config.boot.kernel.enable")" != "true" ]; then
      jq --arg h "$host" '.[$h] = {kernel: null, initrd: null, modules: null}' "$out" > "$out.tmp"
      mv "$out.tmp" "$out"
      echo "::endgroup::" >&2
      continue
    fi
    k=$(nix eval --raw ".#nixosConfigurations.$host.config.system.build.kernel")
    i=$(nix eval --raw ".#nixosConfigurations.$host.config.system.build.initialRamdisk")
    m=$(nix eval --raw ".#nixosConfigurations.$host.config.system.modulesTree")
    jq --arg h "$host" --arg k "$k" --arg i "$i" --arg m "$m" \
      '.[$h] = {kernel: $k, initrd: $i, modules: $m}' "$out" > "$out.tmp"
    mv "$out.tmp" "$out"
    echo "::endgroup::" >&2
  done < <(nix eval .#nixosConfigurations --apply builtins.attrNames --json | tr -d '[]" ' | tr ',' '\n' | grep .)
}

compare() {
  local before="$1" after="$2"
  # Store path basenames carry the version (linux-6.18.49), so the diff reads
  # as a version change without evaluating anything extra.
  jq -r -s '
    .[0] as $a | .[1] as $b
    | [ $b | to_entries[]
        | .key as $h | .value as $new | ($a[$h] // {}) as $old
        | { host: $h,
            changed: [ "kernel", "initrd", "modules" ]
                     | map(select($old[.] != $new[.])) }
      ] as $rows
    | ( $rows | map(select(.changed | length > 0)) ) as $reboot
    | if ($reboot | length) == 0 then
        "All hosts can take this bump with a plain `switch`; nothing touches the kernel, the initrd or the modules tree."
      else
        "### Hosts that need `boot` + reboot, not `switch`\n\n"
        + "| Host | Changed | Why it matters |\n|---|---|---|\n"
        + ( $reboot
            | map("| `\(.host)` | \(.changed | join(", ")) | "
                  + (if (.changed | index("modules")) then
                       "out-of-tree modules move with it; new userspace will not initialise against the loaded ones"
                     else "new kernel does not take effect until reboot" end)
                  + " |")
            | join("\n") )
        + "\n\n```bash\ndeploy .#<host> --boot   # then reboot\n```\n\n"
        + "A plain `switch` on these will either under-apply or fail activation outright.\n\n"
        + ( ( $rows | map(select(.changed | length == 0)) ) as $ok
            | if ($ok | length) > 0 then
                "`switch` is fine for: " + ($ok | map("`\(.host)`") | join(", ")) + "."
              else "" end )
      end
  ' "$before" "$after"
}

case "${1:-}" in
  record) record "$2" ;;
  compare) compare "$2" "$3" ;;
  *) echo "usage: $0 record <out.json> | compare <before.json> <after.json>" >&2; exit 2 ;;
esac
