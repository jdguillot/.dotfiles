#!/usr/bin/env bash
# Works out which hosts this bump cannot fully apply with `switch` alone.
#
# Same comparison nixos-rebuild makes to decide whether a reboot is pending,
# only across the bump rather than against the running system: if `kernel`,
# `initrd` or the modules tree changes, switching installs the new userspace
# beside the old loaded kernel modules and the change does not take effect
# until reboot.
#
# Two different things come out of that, and conflating them overstates the
# work every week:
#
#   * kernel/initrd/modulesTree moved -- the new kernel is installed and the
#     bootloader points at it, but the machine keeps running the old one
#     until it reboots. `switch` is correct here; this is an ordinary pending
#     reboot, not a reason to withhold activation. Note `boot` does not help:
#     both install the kernel, and only the reboot runs it.
#
#   * an out-of-tree module's DRIVER version moved -- nvidia being the only
#     one in this fleet. Here `switch` actively breaks: the new userspace
#     library and the still-loaded module disagree on version, NVML refuses
#     to initialise, and nvidia-container-toolkit-cdi-generator fails and
#     takes docker and everything behind it with it. This host must take the
#     change with `deploy --boot` and a reboot.
#
# The driver version is compared with the kernel suffix stripped, because a
# kernel-module derivation is rebuilt (and renamed) for every kernel bump
# even when the driver itself is untouched: 595.99.02-6.18.49 and
# 595.99.02-6.18.50 are the same driver, and a module loaded from one works
# against userspace from the other.
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
    local k i m kv oot
    # WSL hosts boot the Windows kernel: boot.kernel.enable is false, so
    # system.build.kernel and initialRamdisk are never defined and evaluating
    # them is a hard error. No bump can require a reboot there, so record them
    # as unchanging and let compare() list them as switch-only.
    if [ "$(nix eval --json ".#nixosConfigurations.$host.config.boot.kernel.enable")" != "true" ]; then
      jq --arg h "$host" '.[$h] = {kernel: null, initrd: null, modules: null, drivers: null}' "$out" > "$out.tmp"
      mv "$out.tmp" "$out"
      echo "::endgroup::" >&2
      continue
    fi
    k=$(nix eval --raw ".#nixosConfigurations.$host.config.system.build.kernel")
    i=$(nix eval --raw ".#nixosConfigurations.$host.config.system.build.initialRamdisk")
    m=$(nix eval --raw ".#nixosConfigurations.$host.config.system.modulesTree")
    # Stripped in jq rather than Nix so the evals stay plain attribute reads;
    # `version` on a kernel-module derivation is "<driver>-<kernel>".
    kv=$(nix eval --raw ".#nixosConfigurations.$host.config.boot.kernelPackages.kernel.version")
    oot=$(nix eval --json ".#nixosConfigurations.$host.config.boot.extraModulePackages" \
      --apply 'map (p: p.version or p.name or "?")')
    jq --arg h "$host" --arg k "$k" --arg i "$i" --arg m "$m" --arg kv "$kv" --argjson oot "$oot" \
      '.[$h] = {kernel: $k, initrd: $i, modules: $m,
                drivers: ($oot | map(sub("-" + $kv + "$"; "")) | sort)}' "$out" > "$out.tmp"
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
                     | map(select($old[.] != $new[.])),
            # A driver version move is the only case `switch` cannot take.
            drivers: (($old.drivers // null) != $new.drivers) }
      ] as $rows
    | ( $rows | map(select(.drivers)) ) as $must
    | ( $rows | map(select(.drivers | not) | select(.changed | length > 0)) ) as $pending
    | ( if ($must | length) > 0 then
          "### Deploy with `--boot`, then reboot\n\n"
          + "| Host | Why |\n|---|---|\n"
          + ( $must
              | map("| `\(.host)` | an out-of-tree module changed driver version; "
                    + "new userspace cannot initialise against the loaded one, "
                    + "so `switch` fails activation |")
              | join("\n") )
          + "\n\n```bash\n"
          + ( $must | map("deploy .#\(.host) --boot") | join("\n") )
          + "\n```\n\nThen reboot those hosts.\n"
        else "" end )
      + ( if ($pending | length) > 0 then
            "### Reboot when convenient\n\n"
            + "`switch` applies these in full; only the new kernel waits for a "
            + "reboot, exactly as on any NixOS machine. No deploy-time action.\n\n"
            + "| Host | Changed |\n|---|---|\n"
            + ( $pending
                | map("| `\(.host)` | \(.changed | join(", ")) |")
                | join("\n") )
            + "\n"
          else "" end )
      + ( if ($must | length) == 0 and ($pending | length) == 0 then
            "Nothing here touches the kernel, the initrd or an out-of-tree module; `switch` applies this bump in full."
          else "" end )
  ' "$before" "$after"
}

case "${1:-}" in
  record) record "$2" ;;
  compare) compare "$2" "$3" ;;
  *) echo "usage: $0 record <out.json> | compare <before.json> <after.json>" >&2; exit 2 ;;
esac
