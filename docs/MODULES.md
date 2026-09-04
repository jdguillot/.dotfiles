# NixOS system modules

This repo's NixOS layer lives in `modules/`. Hosts mostly set `cyberfighter.*` options and let the modules translate those values into upstream NixOS settings.

## Namespace map

A small but important detail: not everything is under `cyberfighter.features.*`.

| Namespace | Purpose |
| --- | --- |
| `cyberfighter.profile.*` | system profile defaults |
| `cyberfighter.traits.*` | per-host purpose flags (`dev`), defaulted from `hosts/default.nix` |
| `cyberfighter.system.*` | host identity, locale, boot, and user metadata |
| `cyberfighter.nix.*` | Nix daemon and CLI settings |
| `cyberfighter.packages.*` | shared package bundles |
| `cyberfighter.filesystems.*` | TrueNAS/CIFS and extra file systems |
| `cyberfighter.features.*` | optional feature modules |

## Layout

```text
modules/
├── core/
│   ├── profiles/
│   ├── system/
│   ├── users/
│   └── nix-settings/
└── features/
    ├── 1password/
    ├── ai/
    │   ├── comfyui/
    │   ├── hermes/
    │   ├── odysseus/
    │   └── ollama/
    ├── bluetooth/
    ├── cachix/
    ├── desktop/
    ├── docker/
    ├── filesystems/
    ├── flatpak/
    ├── fonts/
    ├── gameserver/
    ├── gaming/
    ├── graphics/
    ├── networking/
    ├── packages/
    ├── printing/
    ├── proxmox/
    ├── searxng/
    ├── security/
    ├── sops/
    ├── sound/
    ├── ssh/
    ├── sunshine/
    ├── syncthing/
    ├── tailscale/
    ├── traefik/
    ├── vpn/
    ├── vscode/
    └── wine/
```

## Profile defaults

`cyberfighter.profile.enable` accepts `desktop`, `wsl`, `minimal`, or `none`; it defaults from the host's `profile` in `hosts/default.nix` (via the `hostMeta` specialArg), as do `system.hostname`, `system.username`, and `system.stateVersion` — hosts only set what deviates.

| Profile | Defaults applied |
| --- | --- |
| `desktop` | enables `features.desktop`, `graphics`, `sound`; sets `networking.networkmanager = true`; enables Flatpak with a small default package set; enables `packages.includeBase` and `packages.includeDesktop`; defaults `bootloader.type` to `systemd-boot` |
| `wsl` | keeps graphics support on, defaults `networking.networkmanager = false`, leaves desktop package bundles off, and defaults `bootloader.type` to `none` |
| `minimal` | keeps package defaults lean, defaults `networking.networkmanager = true`, keeps desktop packages off, defaults `bootloader.type` to `systemd-boot`, and disables sleep/hibernate targets |
| `none` | applies no bundled defaults |

## Core and top-level modules

### `cyberfighter.traits`

`modules/core/traits/default.nix` — one file imported by BOTH the system
and Home Manager module trees. Each trait named on a host's `traits`
list in `hosts/default.nix` becomes a `cyberfighter.traits.<name>` bool
(via the `hostMeta` specialArg) that module defaults key off; either
side can override its copy independently. Current traits: `dev` (drives
`packages.includeDev`, home agent tooling, dev CLIs, full LazyVim).
Adding a trait: add the name to `knownTraits` in the module, declare it
on hosts, gate module defaults on `config.cyberfighter.traits.<name>`.

### `cyberfighter.profile`

- `cyberfighter.profile.enable`

See the profile table above for what each value turns on by default.

### `cyberfighter.system`

Used by every host for shared system metadata.

Key options:

- `cyberfighter.system.hostname`
- `cyberfighter.system.username`
- `cyberfighter.system.userDescription`
- `cyberfighter.system.extraGroups`
- `cyberfighter.system.timeZone`
- `cyberfighter.system.locale`
- `cyberfighter.system.stateVersion`
- `cyberfighter.system.bootloader.type`
- `cyberfighter.system.bootloader.secureBoot`
- `cyberfighter.system.bootloader.efiCanTouchVariables`
- `cyberfighter.system.bootloader.luksDevice`
- `cyberfighter.system.windowsUsername`

#### Choosing a bootloader

`bootloader.type` is one choice, not a flag per loader, because every loader
defines `system.build.installBootLoader` -- enabling two is a conflict rather
than a combination.

| Value | Use it when |
| --- | --- |
| `systemd-boot` | Default for everything. No Secure Boot. |
| `lanzaboote` | Secure Boot wanted. Kernel, initrd and cmdline are packed into one signed image the firmware verifies directly, which is also what TPM-sealed LUKS unlocking is built on. Costs ESP space: every generation carries its own copy of the initrd, hence the built-in `configurationLimit = 10`. |
| `limine` | Secure Boot optional, and useful when a menu that can chainload another OS across disks matters -- systemd-boot only discovers Windows on its own ESP. Signing is opt-in via `secureBoot`; the chain is signed loader -> config hash enrolled into it -> checksummed kernel/initrd, rather than a firmware-verified unified image. |
| `none` | WSL and containers, where NixOS does not own the boot process. |

`secureBoot` is implied by `lanzaboote` and rejected for `systemd-boot`. Either
way it expects an sbctl PKI at `/var/lib/sbctl`, so on a new host run
`sbctl create-keys` before the first switch, then
`sbctl enroll-keys --microsoft` before turning Secure Boot on in firmware --
the Microsoft keys keep Windows bootable and let signed option ROMs (e.g. an
NVIDIA GPU) initialise.

Upstream references:

- NixOS boot options: <https://mynixos.com/search?q=boot.loader>
- NixOS user options: <https://mynixos.com/search?q=users.users>

### `cyberfighter.nix`

Repo-level Nix settings, including the shared substituters used here.

Key options:

- `cyberfighter.nix.enableDevenv`
- `cyberfighter.nix.trustedUsers`
- `cyberfighter.nix.keepOutputs`
- `cyberfighter.nix.keepDerivations`
- `cyberfighter.nix.extraOptions`
- `cyberfighter.nix.garbageCollect`
- `cyberfighter.nix.optimize`

Notes:

- When `enableDevenv = true`, the module enables the Cachix/substituter set used by this repo, including `devenv`, `jdguillot`, `nix-community`, `niri`, `noctalia`, and `proxmox-nixos` caches.
- The module also creates a SOPS-backed GitHub access-token include for `nix.conf`.

Upstream references:

- Nix settings: <https://nix.dev/manual/nix/stable/command-ref/conf-file>
- MyNixOS Nix search: <https://mynixos.com/search?q=nix.settings>

### `cyberfighter.packages`

Shared package bundles that profiles and hosts can mix and match.

Key options:

- `cyberfighter.packages.includeBase`
- `cyberfighter.packages.includeDev`
- `cyberfighter.packages.includeDesktop`
- `cyberfighter.packages.includeVirt`
- `cyberfighter.packages.extraPackages`

Notes:

- `includeBase` is the gate for the combined package list and the `trash-empty` systemd service.
- `includeDev` defaults to `config.cyberfighter.traits.dev` — hosts declare the trait in `hosts/default.nix` instead of setting this per host.
- Base packages include a troubleshooting toolkit: `htpasswd` (Apache), `openssl`, `curl`, `bind` (dig/host), `netcat`, `socat`, `tcpdump`, `strace`.
- Development packages include tooling such as `deploy-rs`, `github-copilot-cli`, `claude-code`, `nixd`, language servers, and Node tooling.
- Desktop packages include `kitty`, `wofi`, `bitwarden-desktop`, and `1Password` GUI packages.

Upstream references:

- Environment packages: <https://mynixos.com/search?q=environment.systemPackages>
- Systemd services: <https://mynixos.com/search?q=systemd.services>

### `cyberfighter.filesystems`

Top-level file system helpers, especially for TrueNAS/CIFS mounts.

Key options:

- `cyberfighter.filesystems.truenas.enable`
- `cyberfighter.filesystems.truenas.server`
- `cyberfighter.filesystems.truenas.mounts`
- `cyberfighter.filesystems.smbCredentials`
- `cyberfighter.filesystems.extraMounts`

Notes:

- When TrueNAS mounts are enabled, the module creates SMB username/password secrets and renders `/etc/nixos/smb-secrets` through `sops-nix`.
- The repo's `razer-nixos` host uses this for personal share mounts.

Upstream references:

- NixOS file systems: <https://mynixos.com/search?q=fileSystems>
- CIFS mount options: <https://nixos.org/manual/nixos/stable/#sec-file-systems>

Example:

```nix
{
  cyberfighter.filesystems.truenas = {
    enable = true;
    server = "truenas.example.internal";
    mounts.home = {
      share = "userdata/myuser";
      mountPoint = "/mnt/truenas-home";
    };
  };
}
```

## Feature modules

### Desktop and hardware

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `desktop` | `enable`, `environment`, `displayManager`, `greeter`, `firefox` | supports `plasma6`, `plasma5`, `gnome`, `hyprland`, `niri`, or `none`; current hosts use `plasma6` and `niri`. `greeter` selects `dms` (default, the DankMaterialShell greeter from the `dank-greeter` input), `regreet`, or `tuigreet`. The `niri` environment also registers a greeter session per desktop shell (`Niri (Noctalia)`, `Niri (DankMaterialShell)`) — see [DESKTOP-STYLES.md](DESKTOP-STYLES.md) | <https://mynixos.com/search?q=services.desktopManager> |
| `graphics` | `enable`, `nvidia.enable`, `nvidia.prime.enable`, `nvidia.prime.intelBusId`, `nvidia.prime.nvidiaBusId`, `nvidia.powerManagement`, `nvidia.openDriver`, `amd.enable` | GPU acceleration and vendor-specific tuning | <https://mynixos.com/search?q=hardware.nvidia> |
| `sound` | `enable` | PipeWire-based sound stack | <https://mynixos.com/search?q=services.pipewire.enable> |
| `fonts` | `enable` | common programming and desktop font packages | <https://mynixos.com/search?q=fonts.packages> |
| `bluetooth` | `enable`, `powerOnBoot`, `extraPackages` | Bluetooth stack and helper tools | <https://mynixos.com/search?q=hardware.bluetooth.enable> |
| `printing` | `enable` | CUPS printing | <https://mynixos.com/search?q=services.printing.enable> |

### Networking and access

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `networking` | `networkmanager` | thin wrapper around NetworkManager enablement | <https://mynixos.com/search?q=networking.networkmanager.enable> |
| `ssh` | `enable`, `ports`, `passwordAuth`, `permitRootLogin`, `authorizedKeys` | OpenSSH server settings | <https://mynixos.com/search?q=services.openssh.enable> |
| `tailscale` | `enable`, `useRoutingFeatures`, `acceptRoutes`, `extraUpFlags` | client and routing flags | <https://mynixos.com/search?q=services.tailscale.enable> |
| `vpn.pia` | `enable`, `autoStart`, `server`, `port`, `credentialsFile` | PIA/OpenVPN workflow; expects SOPS when credentials are secret-backed | <https://mynixos.com/search?q=services.openvpn.servers> |

### Packaging and applications

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `flatpak` | `enable`, `browsers`, `cad`, `electronics`, `gaming`, `extraPackages` | wraps `nix-flatpak` with category toggles | <https://mynixos.com/search?q=services.flatpak> |
| `cachix` | `enable` | turns on repo Cachix integration; asserts SOPS is enabled | <https://mynixos.com/search?q=nix.settings.substituters> |
| `onepassword` | `enable` | system-side 1Password integration | <https://mynixos.com/search?q=1password> |
| `vscode` | `enable` | system package integration for VS Code | <https://mynixos.com/search?q=vscode> |
| `wine` | `enable` | Wine support for Windows apps | <https://mynixos.com/search?q=wine> |

### Services and infrastructure

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `docker` | `enable`, `rootless`, `enableOnBoot`, `networks` | Docker engine plus optional named bridge networks | <https://mynixos.com/search?q=virtualisation.docker.enable> |
| `compose` | `projects.<name>` (`files`, `networks`, `envFile`, `prepare`, `runtimeDirectory`, `timeout`, `extraUpFlags`, `restartTriggers`) | shared scaffolding for compose projects as boot-time systemd oneshots — owns the unit ordering/lifecycle invariants and a `<name>-compose` day-2 wrapper; traefik, litellm, comfyui, and odysseus declare their projects through it | <https://docs.docker.com/compose/> |
| `traefik` | `enable`, `dnsDomain`, `email`, `network`, `routes.<name>` (`host`, `port`, `auth`, `backend`, `extraHosts`, `network`), `dnsResolvers`, `rateLimit`, `dynamicFiles`, `secrets.*` | TLS-terminating reverse proxy as a compose project; declares its own sops secrets (name-style, `*File` escape hatches); `routes` declares a routed service once and the module renders it as docker labels (`routeLabels`/`routeLabelFiles`) or a file-provider fragment, owning the entrypoint/cert-resolver/middleware-chain spelling; `dynamicFiles` stays as the escape hatch for routing `routes` cannot express | <https://doc.traefik.io/traefik/> |
| `attic` | `enable`, `port`, `apiEndpoint`, `storage`, `localPath`, `s3.endpoint`, `s3.bucket`, `s3.region`, `retentionPeriod`, `openFirewall`, `secrets.environment`, `environmentFile` | self-hosted Nix binary cache server (`services.atticd`, monolithic); chunks go to a local path — typically an NFS mount from TrueNAS, with atticd pinned to uid 568 (`apps`) for stable NFS ownership — or an S3 bucket; one sops env file carries the RS256 JWT secret (plus `AWS_*` keys for s3); pair with a traefik `routes` entry (`backend = "host"`, `auth = "none"`) for TLS | <https://docs.attic.rs/> |
| `github-runner` | `enable`, `url`, `name`, `count`, `ephemeral`, `extraLabels`, `extraPackages`, `secrets.token`, `tokenFile` | native self-hosted GitHub Actions runner (`services.github-runners`); jobs share the host's `/nix/store` and nix-daemon, so there is no per-job disk budget; ephemeral by default since the repo is public — pair with "Require approval for all outside collaborators" | <https://mynixos.com/search?q=services.github-runners> |
| `security` | `firejail` | lightweight sandboxing toggle | <https://mynixos.com/search?q=programs.firejail.enable> |
| `sops` | `enable`, `defaultSopsFile`, `sshKeyPath`, `deployUserAgeKey` | wraps `sops-nix`; can derive a user age key from the host SSH key | <https://github.com/Mic92/sops-nix> |
| `proxmox` | `enable`, `ipAddress` | Proxmox VE integration via `proxmox-nixos` | <https://github.com/SaumonNet/proxmox-nixos> |

### AI agents

`cyberfighter.features.ai.*` groups self-hosted AI runtimes. Each one has its
own `enable`, so turning on one does not pull in the others.

The split that matters: **`ollama` serves models, everything else consumes
them.** Agents (`ai.hermes` natively, `ai.odysseus` from a container) point their
`base_url` at one shared server. Letting each agent bring its own runtime means
N copies of the weights resident on one GPU.

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `ai.ollama` | `enable`, `acceleration`, `modelsDir`, `models`, `syncModels`, `host`, `port`, `exposeToContainers`, `keepAlive`, `maxLoadedModels`, `numParallel`, `flashAttention`, `kvCacheType`, `groupMembers`, `environmentVariables` | local OpenAI-compatible inference server at `/v1` | <https://mynixos.com/search?q=services.ollama> |
| `ai.hermes` | `enable`, `configFile`, `model`, `settings`, `mcpServers`, `stateDir`, `workingDirectory`, `addToSystemPackages`, `groupMembers`, `extraPackages`, `environment`, `extraEnvironmentFiles`, `secrets.envSecret`, `secrets.sopsFile`, `backend.*`, `container.*` | wraps `hermes-agent.nixosModules.default`; runs the Hermes gateway as a systemd service | <https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup> |
| `ai.odysseus` | `enable`, `src`, `patches`, `researchProbeTimeout`, `projectName`, `stateDir`, `bind`, `port`, `auth`, `allowedOrigins`, `ollamaBaseUrl`, `llmHost`, `bundledSearxng`, `searxngInstance`, `bridgeName`, `puid`, `pgid`, `extraEnv`, `secrets.envSecret`, `secrets.sopsFile` | self-hosted AI workspace; a systemd oneshot drives `docker compose` off a pinned source tree | <https://github.com/odysseus-dev/odysseus> |
| `searxng` | `enable`, `package`, `listen`, `port`, `baseUrl`, `jsonApi`, `limiter`, `openFirewall`, `exposeToContainers`, `secretKeyFile`, `settings` | host-native metasearch (lives outside `ai.*` -- the AI stack is just one client), usable on its own and as the search backend for `ai.odysseus` | <https://mynixos.com/search?q=services.searx> |
| `ai.comfyui` | `enable`, `modelsDir`, `user`, `group`, `hfTokenFile`, `models` | declarative checkpoint downloads only; the runtime itself is `ai.comfyui.server` | <https://github.com/comfyanonymous/ComfyUI> |
| `ai.comfyui.server` | `enable`, `bind`, `port`, `cliArgs`, `dataDir`, `userDataDir`, `user`, `group` | ComfyUI itself: the shared native compose.yaml rendered per host, run by a systemd oneshot (`comfyui-compose` for day-2 ops) | <https://github.com/comfyanonymous/ComfyUI> |
| `ai.comfyui.openaiApi` | `enable`, `comfyuiUrl`, `listen`, `port`, `workflows`, `freeAfterRun`, `timeout`, `exposeToContainers` | translates `/v1/images/generations` to a ComfyUI workflow run, so image clients can use ComfyUI as a model | <https://docs.comfy.org/development/comfyui-server/comms_routes> |

#### Local inference (`ai.ollama`)

`acceleration` picks a package variant (`ollama-cuda`, `-rocm`, `-vulkan`,
`-cpu`); the upstream `services.ollama.acceleration` option no longer exists.
CUDA and ROCm variants are **not** in `cache.nixos.org` -- CUDA is unfree, so
Hydra never builds them. `cyberfighter.nix` ships `cache.nixos-cuda.org` for
this reason; without a substituter that has them, a rebuild compiles Ollama
locally.

**The first switch that adds the cache cannot use it.** `nixos-rebuild` builds
before it activates, and the build runs against the previous generation's
`nix.conf`. Measured difference on `ollama-cuda`:

```text
without the cache:  2 derivations built (cuda-merged-12, ollama) + 233MB fetched
with the cache:     0 built, one 1.2GiB fetch
```

Pass it by hand for that one rebuild (see the BOOTSTRAP comment in
`modules/core/nix-settings/default.nix`), or switch twice.

VRAM is the binding constraint, and it is spent on more than weights:

```text
weights   = params x bits_per_weight / 8      Q4_K_M ~ 4.8bpw, Q6_K ~ 6.6bpw
KV cache  = 6-10GB at 64-128K context         halved by kvCacheType = "q8_0"
            scales with numParallel
desktop   = 1-2GB if a compositor shares the GPU
```

Agentic workloads are context-hungry, so a lower quantisation at high context
generally beats a higher one at low context. Pin exact tags in `models` --
a floating tag like `:30b` can change quantisation upstream and move the budget
out from under you.

`maxLoadedModels = 2` is the useful default whenever an agent uses a small
auxiliary model for side tasks (compression, title generation, tool-call
judging). With one slot, every side call evicts the primary model and pays a
multi-gigabyte reload.

`keepAlive` trades warm-start latency against handing the card back. `"-1"`
pins forever, which is right for a headless box and wrong for one that also
games.

#### Hugging Face models

Any GGUF repo on the Hub can be pulled directly, no Modelfile needed:

```bash
ollama pull hf.co/{user}/{repo}:{QUANT}     # huggingface.co also works
```

GGUF repos only -- a safetensors repo will not work. Omitting the quant tag
gets `Q4_K_M` when the repo has it, otherwise whatever Ollama considers
reasonable; always name it explicitly when VRAM is tight. Quant tags are
case-insensitive and the full `.gguf` filename works as a tag too.

Models pulled by hand persist: with `syncModels = false` (the default) the
loader unit only ever runs `ollama pull` on the declared list and never
reconciles. Pull ad hoc to evaluate, then paste the exact `ollama list` name
into `models` for reproducibility. Setting `syncModels = true` makes the next
deploy delete everything not declared.

**Gated and private repos use two different credentials**, and it is easy to set
up the wrong one:

| Path | Credential | Location |
| --- | --- | --- |
| `ollama pull hf.co/...` | Ollama's SSH key, added at <https://huggingface.co/settings/keys> | `/var/lib/ollama/.ollama/id_ed25519.pub` |
| `hf download` | token from `hf auth login` | `~/.cache/huggingface/token` |

`hf auth login` does **not** unlock `ollama pull`. Note also that the pubkey
lives in the *service* user's home (`services.ollama.home`), not yours -- HF's
own docs say `~/.ollama/`, which is wrong here -- and it only exists after the
service has started once.

When only the token route is available, download and register manually:

```bash
hf download {user}/{repo} {file}.gguf --local-dir .
printf 'FROM ./%s.gguf\n' {file} > Modelfile
ollama create {name} -f Modelfile
```

#### Reaching the server from containers

`exposeToContainers = true` binds `0.0.0.0` and opens the port on every
bridge registered in `cyberfighter.features.docker.containerBridges`
**only** (docker0 plus each compose module's published bridge). This is not
`networking.firewall.allowedTCPPorts`, which would expose an unauthenticated
inference server to the whole LAN.

It is needed because inside a container `127.0.0.1` is the container's own
loopback, not the host, so a loopback-bound server is unreachable no matter what
the client config says.

Native host clients should still use loopback. Hermes in particular: upstream's
`runtime_provider.py` only trusts a configured `base_url` to back bare `custom`
provider resolution when the host is loopback.

#### Two configuration modes

`configFile` defaults to `null`: `config.yaml` is generated from `model`,
`settings` and `mcpServers`, deep-merged with runtime edits on disk.

Point `configFile` at a host's own YAML to install it verbatim as
`$HERMES_HOME/config.yaml` instead -- the whole agent behaviour then lives in
one readable file (see `hosts/ryzn-server/hermes-config.yaml`). In that mode
upstream ignores `settings` entirely, so `model`, `settings` and `mcpServers`
are rejected by an assertion -- edit the YAML instead.

Everything outside `config.yaml` (state dir, backend, container mode, secrets)
works the same in both modes.

#### Pointing Hermes at a local model

Upstream routes every OpenAI-compatible endpoint through one provider profile,
`custom` (aliases: `ollama`, `local`, `vllm`, `llamacpp`). It takes no API key
and requires an explicit `base_url`:

```yaml
model:
  default: "qwen3-coder:30b-a3b-q4_K_M"
  provider: "custom"
  base_url: "http://127.0.0.1:11434/v1"
  context_length: 65536

providers:
  custom:
    request_timeout_seconds: 600
```

Two settings that are easy to get wrong:

- **`context_length` must be set by hand.** Upstream normally auto-detects it
  and says so, but names this exact case as the exception: a local server with a
  custom `num_ctx`. Auto-detection reads the model's *native* window, not the KV
  cache the GPU can hold, so Hermes compresses too late and then overflows VRAM.
- **`request_timeout_seconds` needs raising.** The first request after an idle
  unload pays a multi-gigabyte read from disk into VRAM before the first token.
  Cloud-tuned defaults give up before that finishes.

Auxiliary tasks can run on a second, much smaller local model via
`auxiliary.<task>.provider = "main"`. Upstream marks non-OpenRouter/Nous
auxiliary providers as experimental, and sanctions exactly this split: text-only
tasks (compression, titles) on the local endpoint, vision left on `"auto"`
because it needs a multimodal model.

#### Secrets

`secrets.envSecret` (default `"hermes-env"`) names a key in the SOPS file holding
a dotenv blob, which sops-nix decrypts and the module appends to
`$HERMES_HOME/.env`:

```yaml
# secrets/secrets.yaml
hermes-env: |
  ANTHROPIC_API_KEY=sk-ant-...
  OPENROUTER_API_KEY=sk-or-...
```

The module declares the `sops.secrets` entry itself, so the host only needs
`cyberfighter.features.sops.enable = true`. API keys must never go in
`config.yaml`, `settings`, or `environment` -- those all land in the
world-readable Nix store.

#### Sharing state with your shell

The gateway owns `/var/lib/hermes` as `hermes:hermes` mode 2770.
`addToSystemPackages = true` puts `hermes` on `PATH` and exports `HERMES_HOME`;
`groupMembers` adds users to the `hermes` group so that shared `HERMES_HOME` is
actually writable. Without the group membership you get the CLI but not access.

Group membership alone is not enough, hence `sharedHomePermissions` (on by
default when both of the above are set). Upstream's `save_config_value`
re-chmods `config.yaml` to `0600` on every runtime persist -- `/model`,
`/approvals always`, TUI toggles -- unconditionally, unlike `_secure_file`,
which does honour managed mode. The activation script installs the file `0660`,
so the first runtime write undoes it and every other group member is locked out.

The failure is silent and misleading: the CLI prints a parse warning, falls back
to the built-in default config, and therefore loses `model.base_url`. The model
picker then shows cloud providers and **no local Ollama models at all**, because
`curated_models_for_provider("custom")` has no endpoint left to probe. A
`systemd.path` unit on `HERMES_HOME` re-applies group ownership after each write.

#### Backend and container mode

`backend.mode` (`none`/`serve`/`dashboard`) starts a second unit,
`hermes-backend`, serving `/api/ws` and `/api/pty` for Hermes Desktop, plus the
admin panel in `dashboard` mode. Binding to a non-loopback address turns on the
auth gate, so set `backend.sessionTokenSecret` too (the module warns if you do
not). `backend.waitFor = "interface"` with `backend.interfaceName = "tailscale0"`
avoids the boot race against `tailscaled`.

`container.enable = true` runs the gateway in an Ubuntu OCI container with a
persistent writable layer, so the agent can `apt`/`pip`/`npm` install things that
survive restarts. Upstream forbids combining it with a backend.

#### Service management

```bash
systemctl status hermes-agent
journalctl -u hermes-agent -f
```

Mutating CLI commands (`hermes setup`, `hermes config edit`) are blocked on
Nix-managed installs; change the Nix config and rebuild instead.

#### ComfyUI as an image model (`ai.comfyui.openaiApi`)

Odysseus, and anything else built for `gpt-image`/`dall-e`, expects an image
*model* behind `POST /v1/images/generations`. ComfyUI expects `POST /prompt`
with a workflow graph. Nothing upstream bridges the two -- every "ComfyUI +
OpenAI" project goes the other way, adding nodes that *call* OpenAI -- so this
module ships a small stdlib-only shim (`comfyui-openai-shim.py`) as a systemd
unit.

Native, not another container: it holds no state, reaches ComfyUI on loopback,
and exists precisely so a second diffusion runtime never lands on the same GPU.

**Be clear about the tradeoff.** A ComfyUI graph gets flattened to
prompt-in/image-out. Anything a workflow does beyond that -- ControlNet, LoRA
stacks, upscale chains, custom nodes -- is invisible to the caller. `workflows`
is how you get that expressiveness back: one file per exposed model, and the
attribute name is the model id clients select.

Workflow files are ComfyUI's **API format** -- "Save (API Format)" in the web
UI, not the editor format the canvas saves by default. Build the graph in
ComfyUI, verify it renders, then export. Placeholders are substituted
structurally after the JSON is parsed, so an input whose value is exactly one of
these is replaced, with no escaping to get wrong:

```text
"%PROMPT%"  "%NEGATIVE%"  "%SEED%"  "%WIDTH%"  "%HEIGHT%"  "%BATCH%"
```

The graph must end in `SaveImage` -- that is what puts the result in ComfyUI's
history for the shim to read back, and it also drops the image in your normal
output directory.

The default workflow drives `flux1-schnell-fp8.safetensors`, which carries its
own CLIP and VAE, so `CheckpointLoaderSimple` is the whole loader story. A GGUF
stack needs its own file: `UnetLoaderGGUF` plus separate `DualCLIPLoader` and
`VAELoader` nodes. Note `EmptySD3LatentImage`, not `EmptyLatentImage` -- Flux
latents are 16-channel and the SD-era node emits 4.

Wiring into Odysseus: add it as a model endpoint with **model type = image**,
base URL `http://host.docker.internal:7860/v1`, then set it as `image_model` in
settings. `exposeToContainers` opens the port on the registered container
bridges only -- same reasoning as `ai.ollama`, and for the same reason it is
not `allowedTCPPorts`.

```bash
curl -s localhost:7860/v1/models          # exposed workflow names
systemctl status comfyui-openai-shim
```

##### VRAM: `freeAfterRun` is load-bearing

ComfyUI keeps a checkpoint resident in VRAM indefinitely after a run. On a card
it shares with Ollama that is not a cache, it is a leak. Measured here: a single
Flux generation left **17.5GB pinned with an empty queue**, after which Ollama
could not load a 19GB model at all --

```text
ollama[1286]: Load failed ... timed out waiting for llama-server to start
```

-- and every Odysseus chat turn failed, with nothing in Odysseus's own logs to
explain why.

`freeAfterRun` (on by default) calls ComfyUI's `POST /free` after every run,
including a run that failed *after* loading the checkpoint, which holds just as
much. Measured across one generation:

```text
before  1,445 MiB
peak   16,549 MiB
after   1,445 MiB      # without freeAfterRun this stays at ~17.5GB
```

The cost is a cold checkpoint read on the next image -- about 25s of a 29s
512x512 schnell run. Same trade as `ai.ollama.keepAlive`, for the same reason:
on a box that also games and serves LLMs, no single runtime gets to pin the GPU.
Turn it off only where ComfyUI owns the card.

The reverse direction is not automatic. `keepAlive` holds Ollama's ~19GB for 30
minutes after an agent session, and a Flux checkpoint will not fit alongside it
-- wait for the unload, or lower `keepAlive`, before generating.

Generations are serialised behind one lock. ComfyUI executes one graph at a time
regardless, and it is what stops a `/free` for one request from unloading the
model underneath another.

#### SearXNG (`searxng`)

A metasearch engine, run natively via `services.searx` rather than in a
container. It is both a website you point a browser at and the search backend
`ai.odysseus` queries -- that dual role is the whole reason it exists as its own
module rather than living inside Odysseus.

Odysseus bundles a SearXNG container of its own, and it works. The reason to
prefer this one is ownership: the bundled instance lives and dies with the
compose project, so an `src` bump or a `systemctl stop odysseus` takes search
down with it, and its `settings.yml` comes from upstream's source tree plus a
named volume rather than from this repo. Running one natively inverts that --
search is a service, and Odysseus is a client of it (`bundledSearxng = false`).

**`jsonApi` is the setting that matters.** Upstream serves `formats: [html]`
only, and every programmatic client needs `json`. Get it wrong and the failure
is silent in the worst way: the web UI keeps working perfectly while API callers
get a bare 403. This one line is the entire reason Odysseus ships a custom
`settings.yml` with its bundled container.

Exposure is scoped the same way `ai.ollama` does it, and for the same reason:

- `openFirewall` puts `port` on the LAN and binds 0.0.0.0. SearXNG has no
  authentication, so that is a trusted-network-only call.
- `exposeToContainers` opens `port` on every bridge registered in
  `cyberfighter.features.docker.containerBridges` (compose modules publish
  theirs). Unlike Docker's published ports, this direction *does* traverse
  INPUT -- a container reaching the host via `host.docker.internal` arrives on
  its own bridge, so without a hole there the packet is dropped.

`baseUrl` is worth setting for anything past loopback. It is what SearXNG stamps
into the OpenSearch descriptor -- what makes "add to browser search engines"
work -- and into image-proxy links; left unset those point at localhost and only
resolve on the host itself.

`limiter` (rate limiting and bot detection, which pulls in a local Redis) is off
by default and should usually stay off here. It exists to keep scrapers off a
*public* instance and cannot tell them apart from your own API clients, so
turning it on without adding those clients to the limiter's pass list is the
normal way JSON search starts returning 429 to Odysseus.

The `server.secret_key` signs session cookies and must not go in the
world-readable store. `secretKeyFile` takes a SOPS-managed environment file
defining `SEARXNG_SECRET_KEY`; left null, a key is generated on first start at
`/var/lib/searxng/secret-key.env` and reused. That is host-local state -- a
rebuilt machine gets a new one, which only invalidates sessions.

Note that `configureUwsgi` is left false, so this runs SearXNG's built-in HTTP
server. Upstream calls uWSGI unnecessary for LAN or local-only use; the tradeoff
to know is that the built-in server logs every query.

#### Odysseus (`ai.odysseus`)

A self-hosted AI workspace -- chat, agents, deep research, documents, email,
notes, calendar -- bundling ChromaDB, SearXNG and ntfy alongside itself.

Upstream publishes **no image and no release tags**, so `build: .` off a source
tree is the supported install. The module pins that tree with `fetchFromGitHub`
(`main`, upstream's curated branch; `dev` is the default and moves faster) and a
systemd oneshot runs `docker compose up -d --build`. Same call as ComfyUI: a bad
upstream commit can never block a `nixos-rebuild`, and the image tag -- here, the
`src` rev -- is the only version pin.

`src` is the sole thing to bump:

```bash
nix-prefetch-url --unpack https://github.com/odysseus-dev/odysseus/archive/<rev>.tar.gz
nix hash convert --to sri --hash-algo sha256 <output>
```

Two details the compose invocation depends on:

- **`-p odysseus`.** The project directory is a store path, so without an
  explicit project name every `src` bump renames the project and orphans its
  named volumes (`odysseus_chromadb-data`, `odysseus_searxng-data`).
- **`bridgeName`.** Compose would name its bridge `br-<random>`, and the
  firewall hole `ai.ollama` opens is per-interface. `host-gateway` resolves to
  `docker0`'s address, but the packet still *arrives* on the compose bridge, so
  `exposeToContainers`' `docker0` rule never matches it. The module pins the
  interface name and opens `ai.ollama.port` on it.

`ollamaBaseUrl` defaults to `http://host.docker.internal:<port>/v1` whenever
`ai.ollama` is enabled with `exposeToContainers`. The `/v1` suffix is required;
the bare root 404s.

**Environment reaches the container through the override, not `--env-file`.**
Compose's `--env-file` only feeds *interpolation*: a key that upstream's
`environment:` block does not already list stops at compose and never reaches
the process. The generated override re-declares every non-compose key for that
reason -- without it, `extraEnv` would silently do nothing.

##### Patches

`patches` applies to `src` before the image is built, via `applyPatches`. Kept
separate from `src` so pointing that at a working clone keeps them, and so
dropping one when it lands upstream is a one-line change rather than a re-pin.
Each file carries its upstream issue in a header comment.

The default one fixes **deep research against a local model**. Upstream probes
the endpoint before starting research (`src/research_handler.py`, a `"hi"` with
`max_tokens=5`) using a hardcoded `timeout=15, max_retries=1`. A cold model load
loses that race, so research fails outright unless an earlier chat happened to
warm the model -- measured here, a cold `qwen3-coder:30b-a3b-q4_K_M` takes
**~40s** to page into VRAM, against a 15s budget. Chat has no such probe, which
is exactly why "say hello first, then research" works.

That is upstream [#4620](https://github.com/odysseus-dev/odysseus/issues/4620),
still open; PR #4628 proposed this same fix and was closed unmerged. The patch
makes the value read `ODYSSEUS_RESEARCH_PROBE_TIMEOUT`, which
`researchProbeTimeout` sets (default 180). Size it against a *cold* load, not a
warm one.

A related trap when debugging this: `DEAD_HOST_COOLDOWN = 20.0` in
`src/llm_core.py` marks a host dead after a connect failure and fast-fails
everything to it for 20s, so an immediate retry also goes nowhere.

##### Dropping the bundled SearXNG

`bundledSearxng = false` removes the SearXNG container from the compose project
and points `SEARXNG_INSTANCE` at something else -- `searxng` on the host by
default, or `searxngInstance` explicitly. ChromaDB and ntfy are untouched.

Upstream ships no switch for this: the service carries no profile, and odysseus
waits on its healthcheck unconditionally. So the override does it with two YAML
tags, both required:

- **`depends_on: !override`** on the odysseus service. Compose *merges*
  `depends_on` across files rather than replacing it, so removing the service
  without also replacing this map fails the project outright with `depends on
  undefined service searxng` -- it never even renders.
- **`searxng: !reset null`**, which removes the service entirely. List-valued
  keys like `ports:` concatenate across files, so there is no way to neutralise
  the service piecemeal.

The now-unreferenced `searxng-data` volume drops out of the rendered config on
its own; the named volume stays on disk until removed by hand.

Two traps worth stating. The bundled container publishes `127.0.0.1:8080`, which
collides with `searxng` on its default port -- there is an assertion for that
pairing. And Odysseus stores a `search_url` in its own settings that wins over
`SEARXNG_INSTANCE` whenever it is non-empty, so a value set in the UI silently
overrides anything configured here; leave that field blank to defer to Nix.

Ports: the UI on `bind`:`port`, and loopback-only `8100` (ChromaDB), `8080`
(SearXNG, when bundled) and `8091` (ntfy). Docker publishes these with its
own DNAT rules, which never traverse the INPUT chain `networking.firewall`
manages -- `bind` and `auth` are the whole access-control story.

The first admin password is printed once:

```bash
journalctl -u odysseus | grep -i password
# same project, for everything else -- needs root, like the unit itself
sudo odysseus-compose logs -f
sudo odysseus-compose exec odysseus sh
```

### Gaming and game hosting

| Module | Main options | Notes | Upstream refs |
| --- | --- | --- | --- |
| `gaming` | `enable`, `steam.enable`, `steam.remotePlay`, `steam.localNetworkGameTransfers`, `steam.gamescopeSession`, `gamemode`, `mangohud`, `protonup`, `extraPackages` | desktop gaming stack | <https://mynixos.com/search?q=programs.steam.enable> |
| `gameserver` | `enable`, `ludusavi.enable`, `ludusavi.schedule`, `ludusavi.path`, `ludusavi.games`, `ludusavi.roots`, `ludusavi.customGames` | backup-aware game server plumbing | <https://mynixos.com/search?q=systemd.timers> |
| `gameserver.astroneer` | `enable`, `serverName`, `gamePort`, `maxPlayers`, `autoSaveInterval`, `openFirewall`, `publicIpFile`, `serverPasswordFile` | AstroTuxLauncher-based Astroneer server | <https://github.com/CreeperHost/AstroTuxLauncher> |
| `gameserver.playit` | `enable`, `package`, `secretPath` | Playit tunnel helper module; note that `vm-gameserver-nix` currently uses `services.playit` directly in the host config | <https://mynixos.com/search?q=playit> |

## Practical examples

### Desktop host

```nix
{
  cyberfighter = {
    # profile and identity default from the host's hosts/default.nix entry
    nix.trustedUsers = [ "root" "myuser" ];

    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };

      graphics.enable = true;
      docker.enable = true;
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
      };
    };
  };
}
```

### Minimal server

```nix
{
  cyberfighter = {
    # profile and identity default from the host's hosts/default.nix entry

    features = {
      ssh = {
        enable = true;
        passwordAuth = false;
        permitRootLogin = "no";
      };

      docker.enable = true;
      tailscale.enable = true;
      sops.enable = true;
    };
  };
}
```

### Astroneer game server

```nix
{
  cyberfighter.features.gameserver = {
    enable = true;
    ludusavi.enable = true;

    astroneer = {
      enable = true;
      serverName = "my-astroneer-server";
      gamePort = 10806;
      maxPlayers = 8;
      openFirewall = true;
      secrets = {
        publicIp = "playit-tunnel-ip";
        serverPassword = "astroneer-server-password";
      };
    };
  };
}
```

## Where to set things

- Put host-specific values in `hosts/<name>/configuration.nix`
- Keep reusable behaviour in `modules/`
- Register metadata in `hosts/default.nix`
- Export hosts and deploy nodes from `flake.nix`

For host-level examples, see [`HOSTS.md`](HOSTS.md). For deployment and first-time installs, see [`DEPLOYMENT.md`](DEPLOYMENT.md).
