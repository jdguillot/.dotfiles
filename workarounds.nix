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
}
