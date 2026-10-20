# The workaround register: temporary fixes this repo carries while waiting
# on something upstream. docs/WORKAROUNDS.md has the schema and the rules.
#
# Every entry is fenced by a `WORKAROUND(<id>)` / `END WORKAROUND(<id>)`
# comment pair, here and in each file it lists, so the weekly run can retire
# it by deleting those blocks once its `resolved` probe says the fix shipped.
{
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
      followup = "https://github.com/immich-app/immich/issues/32375";
    };
    # 23462 closed on v3.3.0's ML rework, but v3.3.x still fills the card
    # with the PP-OCRv6 models; 32375 is the open report for that, so it is
    # the probe. A close says nothing about the pinned tag carrying the fix.
    resolved = {
      kind = "issue";
      url = "https://github.com/immich-app/immich/issues/32375";
    };
    retire = "manual";
    removal = ''
      Delete the fenced `ocr = false;` line on thkpd-pve1 (the option
      defaults to true), bump `immich.version` to a release that carries the
      fix, deploy, then run the OCR job for "Missing" assets from the admin
      Jobs page and watch `nvidia-smi` on ryzn-server stay flat.
    '';
  };
  # END WORKAROUND(immich-ocr-vram)

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
}
