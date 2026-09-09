# Deployment and provisioning

This repo supports three common workflows:

- local rebuilds on an existing NixOS machine
- remote activation with `deploy-rs`
- first-time machine provisioning with `nixos-anywhere` and `disko`

## Which method should you use?

| Goal | Recommended tool |
| --- | --- |
| update the machine you are sitting at | `nixos-rebuild` and `home-manager switch` |
| push a config to an already-installed remote NixOS machine | `deploy-rs` |
| install a brand-new host over SSH | `nixos-anywhere` |

## Flake outputs in this repo

The flake currently exports:

- `nixosConfigurations` for 8 hosts
- `homeConfigurations` for 7 user@host targets
- `deploy.nodes` for 4 remote targets
- `checks` based on `deploy-rs.lib.<system>.deployChecks`

Use `nix flake show` to inspect the current outputs:

```bash
nix flake show
```

## Local rebuilds

Switch a local NixOS host:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

Switch only the Home Manager config:

```bash
home-manager switch --flake .#<user>@<hostname>
```

Test a system build without a full switch:

```bash
sudo nixos-rebuild test --flake .#<hostname>
```

Useful aliases defined by the Home Manager shell module:

- `ns` - system rebuild plus matching Home Manager switch
- `hs` - Home Manager switch only
- `nu` - `nix flake update`
- `nb` - build without switching

### Rate-limited GitHub fetches (work network)

`codeload.github.com` — the host that actually serves flake-input
tarballs — rate-limits per IP and ignores `access-tokens`, so on a
shared work egress IP fetches 429 no matter how valid the PAT is (the
error is misleadingly reported under the `api.github.com` URL). Skip
GitHub entirely and copy the locked sources from a host that already
has them:

```bash
scripts/copy-flake-inputs.sh                 # all missing input sources
scripts/copy-flake-inputs.sh hermes-agent    # one input
```

Defaults to pulling from ryzn-server over Tailscale (resolved with
`tailscale ip` for a stable IP even when MagicDNS is off); pass
`user@host` as the second argument to use another source store. Store paths are
computed from `flake.lock` narHashes, so nothing touches the network
except the `nix copy` itself.

### Distributed builds (razer-nixos → ryzn-server)

razer-nixos offloads derivations to ryzn-server via
`cyberfighter.nix.remoteBuilders` (which feeds `nix.buildMachines`).
Authentication is Tailscale SSH — port 22 on the tailnet address is
intercepted by tailscaled, tailnet ACLs authorize the connection, and no key
material exists on either side. The Tailscale per-node host key is pinned in
`programs.ssh.knownHosts` in the razer host config because the nix-daemon's
SSH runs in batch mode.

Behavior to know:

- The builder is preferred, never required. When ryzn-server is off or
  unreachable, each derivation logs a `cannot build on ssh://…` warning,
  waits out one SSH timeout, and builds locally. `--builders ""` forces
  local for a single invocation when working offline.
- `builders-use-substitutes` is on: ryzn-server pulls dependencies from the
  binary caches itself rather than over the SSH pipe from the laptop.
- `sshUser` is `cyberfighter`, which is in `trusted-users` on ryzn-server —
  required so locally-built (unsigned) inputs can be uploaded.

## `deploy-rs`

This repo currently exports these deploy nodes:

| Node | Profiles |
| --- | --- |
| `sys-galp-nix` | `system`, `home` |
| `thkpd-pve1` | `system`, `home` |
| `vm-gameserver-nix` | `system`, `home` |
| `simple-vm` | `system` only |
| `ryzn-server` | `system`, `home` |

### Common commands

Deploy one node:

```bash
deploy .#sys-galp-nix
```

Deploy only one profile:

```bash
deploy .#vm-gameserver-nix.system
deploy .#vm-gameserver-nix.home
```

Dry-run activation:

```bash
deploy --dry-activate .#thkpd-pve1
```

Deploy all configured nodes:

```bash
deploy .
```

### How profiles are wired

`flake.nix` uses `mkDeployNode` to build:

- a `system` profile as `root`
- an optional `home` profile as the host's main user
- `profilesOrder = [ "system" "home" ]` when both are present

That means a host can be exported as either:

- system only, like `simple-vm`
- system plus Home Manager, like `sys-galp-nix`

### Adding a new deploy target

1. Add host metadata to `hosts/default.nix`.
2. Create `hosts/<name>/configuration.nix`.
3. Export the host under `nixosConfigurations`.
4. Export a Home Manager target under `homeConfigurations` if needed.
5. Add a deploy node under `deploy.nodes`.

Example pattern:

```nix
deploy.nodes.my-host = mkDeployNode "my-host" hostConfigs.my-host true;
```

Set the last argument to `false` if you only want the system profile.

### Unattended deploys: `deptui-agent`

`ryzn-server` runs `deptui-agent` (the daemon from the same
[deptui](https://github.com/jdguillot/deptui) flake input that provides
the TUI), enabled through `cyberfighter.features.deptui-agent` (see
`docs/MODULES.md`). It tracks this repo's `latest` tag rather than `main`:
`ci.yml` moves the tag only after every host built, the checks passed
and the closures reached the caches, then kicks the agent (see
`docs/CI.md`). Deploys go to every deploy node — both profiles — from the
agent's own private clone, so nothing ever deploys from a dirty working
tree, and never from a commit CI has not vetted. The monthly cron on both
watches is a safety net for a missed kick, not the normal path.

Operational notes:

- Manual `deploy` runs still work and take no lock; the deptui TUI warns
  and offers to pause the agent when you deploy an agent-managed host.
- The agent generates its own ssh identity on first start;
  `deptui-agent pubkey` prints the public half, which lives in the
  shared `ssh.authorizedKeys` so every host already trusts it. Host keys
  come from the `system.hostKey` pins in `hosts/default.nix` where set,
  and are learned on first contact otherwise
  (`StrictHostKeyChecking=accept-new`).
- A failed host is parked until the tag moves again or a kick; a host that
  was simply offline is caught up automatically when it answers again.
- Kick it instead of waiting for the next poll — locally
  (`deptui-agent kick --watch fleet`, socket access via the `deptui-agent`
  group; this is what CI does, since the runners are on the same host) or
  over TCP from elsewhere:

  ```bash
  curl -X POST -H "Authorization: Bearer $TOKEN" "http://ryzn-server:7337/kick?watch=fleet"
  ```

  where `$TOKEN` is the `deptui-agent-listen-token` sops secret
  (`sops -d --extract '["deptui-agent-listen-token"]' secrets/secrets.yaml`).
  A kick names no ref: it deploys whatever `latest` points at, nothing more.

## `nixos-anywhere`

For first-time installs, the repo includes `scripts/nixos-anywhere.sh`, which wraps `nixos-anywhere` with repo-specific helpers.

### What the helper script does

The script can:

- prompt for or accept `--hostname`
- accept a target like `root@192.168.1.50` plus extra SSH flags after `--target`
- generate `hardware-configuration.nix`
- update `.sops.yaml` recipients and run `sops updatekeys`
- open `home/modules/features/ssh/ssh-hosts.yaml` and prepare a new SSH alias entry
- add the new host alias to one or more `home/<user>/home.nix` files
- stage host SSH keys from 1Password before installation

### Main flags

| Flag | Meaning |
| --- | --- |
| `--hostname`, `-n` | host name to provision |
| `--target`, `-t` | SSH target followed by extra SSH flags such as `-i`, `-J`, `-p`, or `-o` |
| `--hardware-config`, `-c` | generate `hardware-configuration.nix` |
| `--no-hardware-config` | skip hardware generation |
| `--secrets`, `-s` | add the host to SOPS recipients |
| `--no-secrets` | skip secrets setup |
| `--ssh-host`, `-S` | add an encrypted SSH host entry |
| `--no-ssh-host` | skip SSH-host integration |
| `--user`, `-u` | add the host alias to one or more Home Manager users; repeatable |

### Practical example

```bash
./scripts/nixos-anywhere.sh \
  --hostname simple-vm \
  --target root@192.168.1.50 -i ~/.ssh/bootstrap-key -p 2222 \
  --hardware-config \
  --secrets \
  --ssh-host \
  --user cyberfighter
```

### Suggested prerequisites for the helper script

If you want the full repo-aware workflow, have these available locally before running it:

- `nixos-anywhere`
- `sops`
- `op` (1Password CLI)
- an editor via `$EDITOR`
- a clipboard helper such as `wl-copy`, `xclip`, `xsel`, `pbcopy`, or `clip.exe`

### New host checklist

Before running `nixos-anywhere`, prepare these repo changes:

1. Choose a template from `hosts/templates/`.
2. Create `hosts/<name>/configuration.nix`.
3. Add host metadata to `hosts/default.nix`.
4. Add the host to `flake.nix`.
5. Add a Home Manager target if the host needs one.
6. Add a `deploy.nodes` entry if it will be maintained remotely.

After the install finishes, update the machine with either:

```bash
deploy .#<hostname>
```

or:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## Templates and matching use cases

| Template | Use it for |
| --- | --- |
| `desktop-workstation.nix` | desktop and laptop installs |
| `gaming-rig.nix` | dedicated gaming desktops |
| `minimal-server.nix` | generic server or VM installs |
| `wsl-dev.nix` | WSL machines |

## Notes for new files

If you add new Nix files as part of a host rollout, make sure they are tracked before running rebuild or switch commands that evaluate the flake.

## Further reading

- `deploy-rs`: <https://github.com/serokell/deploy-rs>
- `nixos-anywhere`: <https://github.com/nix-community/nixos-anywhere>
- `disko`: <https://github.com/nix-community/disko>
- NixOS manual: <https://nixos.org/manual/nixos/stable/>
