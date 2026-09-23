# The workaround register: temporary fixes this repo carries while waiting
# on something upstream. docs/WORKAROUNDS.md has the schema and the rules.
#
# Every entry is fenced by a `WORKAROUND(<id>)` / `END WORKAROUND(<id>)`
# comment pair, here and in each file it lists, so the weekly run can retire
# it by deleting those blocks once its `resolved` probe says the fix shipped.
{
  # WORKAROUND(wsl-prerelease-shared-memory)
  wsl-prerelease-shared-memory = {
    title = "WSL pre-release channel for the WSLg shared-memory fix";
    added = "2026-09-11";
    hosts = [ "work-nix-wsl" ];
    problem = ''
      WSL 2.7.x never mounts /mnt/shared_memory in the WSLg system distro, so
      weston's startup probe fails and the whole session runs in RAIL copy
      mode. Windows then intermittently never gets a first frame for a new
      window: the taskbar icon appears, the app is alive, nothing is drawn.
    '';
    workaround = ''
      The Windows host runs `wsl --update --pre-release` (2.9.11 at the time
      of writing). Nothing in this repo changes; the fix is in WSL's
      DeviceHost package, which the 2.7.x stable line has not picked up.
    '';
    files = [ ];
    upstream = {
      issue = "https://github.com/microsoft/WSL/issues/40618";
      fix = "https://github.com/microsoft/WSL/pull/41499";
    };
    resolved = {
      kind = "release";
      repo = "microsoft/WSL";
      minVersion = "2.9.10";
      prerelease = false;
    };
    retire = "manual";
    removal = ''
      On the Windows host run `wsl --update` (no `--pre-release`) to return to
      the stable channel, confirm `wsl --version` is at or past the release
      the probe named, then delete this entry.
    '';
  };
  # END WORKAROUND(wsl-prerelease-shared-memory)

  # WORKAROUND(immich-ocr-vram)
  immich-ocr-vram = {
    title = "Immich OCR off: the CUDA ML container's VRAM grows without bound";
    added = "2026-09-12";
    hosts = [
      "thkpd-pve1"
      "ryzn-server"
    ];
    problem = ''
      Immich's OCR detection model (PP-OCRv5) makes ONNX Runtime's CUDA
      arena grow with every distinct input shape and never shrink; the
      detector scales the short edge to maxResolution and leaves the long
      edge unbounded, so shapes keep varying. On ryzn-server the ML
      container reached 13 GiB of VRAM for ~2 GiB of models. When Ollama
      then loads the 27B, the card is over-committed and every ML request
      fails with a CUDA allocation error, so thkpd-pve1 falls back to its
      local OpenVINO container and its own CPU. Upstream has an open PR
      adding arena shrinkage, but says a larger ML rework will replace it.
    '';
    workaround = ''
      thkpd-pve1 sets `cyberfighter.features.immich.machineLearning.ocr =
      false`, which renders `machineLearning.ocr.enabled: false` into
      Immich's system settings: no OCR jobs are queued to either ML
      container. Text search over already-processed assets keeps working.
    '';
    files = [ "hosts/thkpd-pve1/configuration.nix" ];
    upstream = {
      issue = "https://github.com/immich-app/immich/issues/23462";
      fix = "https://github.com/immich-app/immich/pull/30332";
    };
    resolved = {
      kind = "issue";
      url = "https://github.com/immich-app/immich/issues/23462";
    };
    retire = "auto";
    removal = ''
      Delete the fenced `ocr = false;` line on thkpd-pve1 (the option
      defaults to true), bump `immich.version` to a release that carries the
      fix, deploy, then run the OCR job for "Missing" assets from the admin
      Jobs page and watch `nvidia-smi` on ryzn-server stay flat.
    '';
  };
  # END WORKAROUND(immich-ocr-vram)

  # WORKAROUND(immich-ml-memory-leak)
  immich-ml-memory-leak = {
    title = "Restart immich-server before its remote-ML memory leak OOMs it";
    added = "2026-09-14";
    hosts = [ "thkpd-pve1" ];
    problem = ''
      Immich v3.2.0 never cancels the response body of its fetch calls to a
      remote machine-learning server, so the server's node process keeps
      roughly one preview image (300-600 KB) per asset sent to ML and only a
      restart frees it. Smart search, face detection and OCR all leak.
      thkpd-pve1 sends ML to ryzn-server, and after a library import ~57k
      smart-search and face-detection jobs would grow the process well past
      its 8g cgroup: the kernel SIGKILLs it mid-job, several times over.
    '';
    workaround = ''
      A minutely systemd timer on thkpd-pve1 runs immich-memory-watchdog.sh,
      which `docker restart`s immich-server (SIGTERM, 60s grace) once the
      `immich` process passes 6.5G RSS and has been up at least 10 minutes.
      The job queue lives in Valkey on disk, so work resumes after the
      restart; only the in-flight jobs are retried.
    '';
    files = [
      "hosts/thkpd-pve1/configuration.nix"
      "hosts/thkpd-pve1/immich-memory-watchdog.sh"
    ];
    upstream = {
      issue = "https://github.com/immich-app/immich/issues/31488";
      fix = "https://github.com/immich-app/immich/pull/31523";
    };
    resolved = {
      kind = "pr";
      url = "https://github.com/immich-app/immich/pull/31523";
    };
    retire = "manual";
    removal = ''
      A merged PR is not enough: `cyberfighter.features.immich.version` is an
      exact tag. Bump it to the first release that carries the fix and deploy,
      then delete the fenced watchdog block in thkpd-pve1's configuration.nix,
      delete hosts/thkpd-pve1/immich-memory-watchdog.sh and this entry. Before
      trusting it, run Smart Search for "All" and confirm `immich` RSS on
      thkpd-pve1 levels off instead of climbing per asset.
    '';
  };
  # END WORKAROUND(immich-ml-memory-leak)

  # WORKAROUND(opencode-1-18-30-prompt-crash)
  opencode-1-18-30-prompt-crash = {
    title = "opencode held at 1.18.21: 1.18.30+ crashes before every prompt";
    added = "2026-09-15";
    hosts = [
      "razer-nixos"
      "ryzn-server"
      "work-nix-wsl"
    ];
    problem = ''
      opencode 1.18.30 throws `TypeError: undefined is not an object
      (evaluating 'a.name')` inside SystemPrompt.environment, on every
      prompt, before any request reaches the model provider. Reporters trace
      it to an undefined node in an Effect layer graph assembled while
      booting the session directory's location service. The TUI and `run`
      both surface it as `UnknownError: Unexpected server error`, which reads
      like the model endpoint failed -- it is opencode's own local server
      reporting its crash, and it sent the operator here chasing a healthy
      Ollama on ryzn-server. Reproduces on an empty project with a stub
      config, an isolated HOME, and any provider. 1.18.31 does not fix it.
    '';
    workaround = ''
      modules/features/packages/default.nix overlays `opencode` from the
      `nixpkgs-opencode` flake input, pinned to nixpkgs c27cdad4 (opencode
      1.18.21, the last packaged version before the regression). Verified by
      running `opencode run -m ollama/qwen3.8:27b-q4_K_M` against
      ryzn-server. The pin is system-wide; the home-manager module sets
      `package = null` and only writes config, so it needs no change.
    '';
    files = [
      "flake.nix"
      "modules/features/packages/default.nix"
    ];
    upstream = {
      issue = "https://github.com/anomalyco/opencode/issues/48372";
    };
    # Watches nixpkgs, not upstream's releases: the workaround is a pin of
    # nixpkgs, so an upstream tag says nothing about whether the fix is
    # reachable from here -- 1.18.32 was cut 2026-09-21 while nixpkgs still
    # carried 1.18.30, the broken one. `input` reads the unoverlaid nixpkgs;
    # the host's own pkgs would report the pinned 1.18.21 forever.
    resolved = {
      kind = "package";
      attr = "opencode";
      input = "nixpkgs";
      minVersion = "1.18.32";
    };
    retire = "manual";
    removal = ''
      The probe only says upstream cut a release past the two known-broken
      ones -- it cannot say the crash is gone, and the issue reports are
      scattered across half a dozen duplicates with no canonical one to
      close, so no probe can. When it fires, re-test by hand: build the
      candidate (`nix build nixpkgs#opencode`) and run `opencode run -m
      <any model> "Reply with exactly: PONG"` in an empty directory. A PONG
      means the fix shipped. Then delete the fenced overlay in
      modules/features/packages/default.nix, the now-unused `inputs` argument
      in that file's header if nothing else uses it, the fenced input in
      flake.nix, `nixpkgs-opencode` from flake.lock (`nix flake update`), and
      this entry. A crash instead means the release is another broken one:
      leave the pin and note the version here.
    '';
  };
  # END WORKAROUND(opencode-1-18-30-prompt-crash)

  # WORKAROUND(proxmox-ticket-signature-interop)
  proxmox-ticket-signature-interop = {
    title = "proxmox-nixos pinned to a fork: PVE tickets fail across a mixed cluster";
    added = "2026-09-21";
    hosts = [ "thkpd-pve1" ];
    problem = ''
      Crypt::OpenSSL::RSA 0.41, which nixpkgs ships, changed the defaults the
      module signs with; stock Proxmox on Debian 13 is still on 0.35-1.1,
      where SHA-1 is the default and the padding was whatever the older
      version did. PVE tickets are exactly that signature, so a proxmox-nixos
      node and a Debian node sharing one authkey produce signatures neither
      can verify: `pveproxy: authentication failure: 401 permission denied -
      invalid PVE ticket`, in both directions, with PVE::Ticket and
      PVE::AccessControl byte-identical on both nodes. It reproduces on two
      hosts sharing a key, with no cluster involved.
    '';
    workaround = ''
      flake.nix pins `proxmox-nixos` to booxter/proxmox-nixos `fix-tickets`,
      the branch behind the upstream pull request, which names SHA-1 and
      PKCS#1 v1.5 explicitly instead of taking whichever defaults the
      installed ::RSA has. Only the flake input moves; the proxmox module and
      thkpd-pve1's config are untouched.
    '';
    files = [ "flake.nix" ];
    upstream = {
      issue = "https://github.com/SaumonNet/proxmox-nixos/issues/256";
      fix = "https://github.com/SaumonNet/proxmox-nixos/pull/258";
    };
    resolved = {
      kind = "pr";
      url = "https://github.com/SaumonNet/proxmox-nixos/pull/258";
    };
    retire = "manual";
    removal = ''
      A fenced URL cannot be deleted automatically -- removing the block
      leaves the flake with no `proxmox-nixos` input at all -- so this is a
      value to put back by hand. When the probe fires, set the input back to
      `github:SaumonNet/proxmox-nixos`, run `nix flake update proxmox-nixos`,
      and deploy thkpd-pve1. Confirm before deleting this entry: log in to
      the web UI on a Debian node and on thkpd-pve1, and check `journalctl -u
      pveproxy` on both for the 401 above. The merge only says the fix is on
      the default branch; the pin is only safe to drop once the lock has
      actually moved to a revision that has it.
    '';
  };
  # END WORKAROUND(proxmox-ticket-signature-interop)
}
