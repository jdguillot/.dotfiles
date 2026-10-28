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

  # WORKAROUND(opencode-v2-no-lsp)
  opencode-v2-no-lsp = {
    title = "opencode held on 1.x (1.19.0): OpenCode 2 does not run language servers";
    added = "2026-10-28";
    hosts = [
      "razer-nixos"
      "ryzn-server"
      "work-nix-wsl"
    ];
    problem = ''
      nixpkgs moved opencode to 2.x on 2026-10-19. OpenCode 2 reads the
      `lsp` block of opencode.json but starts no servers until upstream
      ports the LSP and formatter services, so the server table
      home/modules/features/tools/lsp feeds it would go dead. 2.x is also
      still churning: 2.2.0 shipped breaking changes in a minor, and nixpkgs
      needed two startup fixes after the 2.0.32 bump.
    '';
    workaround = ''
      The `pin` below takes `opencode` from nixos-unstable 09063bd1 (1.19.0,
      the last channel release on 1.x; 1.19.1-1.19.3 only reached master);
      package-pins.nix turns it into an overlay on every host and home.
      Upstream still ships 1.x, and from 1.19.2 its update check never
      offers 2.x.
    '';
    files = [ ];
    pin = {
      attr = "opencode";
      rev = "09063bd1f2b36fd9fd793c36dfade7bd40a93dfc";
      narHash = "sha256-Mh0PUaIv4nFY+8wAGonaEh8iBzwsmdNlwjVHmFg1Biw=";
      version = "1.19.0";
    };
    upstream = {
      issue = "https://github.com/anomalyco/opencode/issues/38528";
    };
    resolved = {
      kind = "issue";
      url = "https://github.com/anomalyco/opencode/issues/38528";
    };
    # Closing the issue says LSP landed in some 2.x, not that the migration
    # is done: the move needs hand work this entry cannot do.
    retire = "manual";
    removal = ''
      Check the release that closed the issue is what nixpkgs ships
      (`nix eval --raw nixpkgs#opencode.version`), then in one commit:
      delete this entry; in home/modules/features/tools/opencode, replace
      `tui` with `cli = { theme.name = cfg.theme; }` (check the shape
      against https://opencode.ai/v2/docs/cli/config) and set
      `validateFiles.cli = true`; decide on `mutableSettings`, since
      OpenCode 2 rewrites cli.json from the TUI. Then verify an LSP
      diagnostic shows up, run `opencode run -m <any model> "Reply with
      exactly: PONG"` in an empty directory, and re-check the CI fix agent
      on ryzn-server with .github/opencode/opencode.json.
    '';
  };
  # END WORKAROUND(opencode-v2-no-lsp)

  # WORKAROUND(pin-mcp-nixos)
  pin-mcp-nixos = {
    title = "mcp-nixos 3.0.1 pinned from nixpkgs 151fa4e: python3Packages.fastmcp-slim is marked broken once nixpkgs' mcp reaches v2 ";
    added = "2026-10-28";
    hosts = [
      "razer-nixos"
      "ryzn-server"
      "work-nix-wsl"
    ];
    problem = ''
      python3Packages.fastmcp-slim is marked broken once nixpkgs' mcp reaches v2 (meta.broken = versionAtLeast mcp.version "2"), and mcp-nixos depends on it through fastmcp; the top-level attribute is the narrowest pin that keeps the hosts that install it evaluating
    '';
    workaround = ''
      The `pin` below takes `mcp-nixos` from nixpkgs 151fa4e, the revision main
      built last, so every host keeps the 3.0.1 it already runs while the
      rest of nixpkgs moves; package-pins.nix turns it into an overlay.
      Added by pin-package.sh from the weekly bump's fix stage.
    '';
    files = [ ];
    upstream = { };
    pin = {
      attr = "mcp-nixos";
      rev = "151fa4e8ddfdd8dd25d945ad94ed54a13de9f6e4";
      narHash = "sha256-Miqqk/ammqnTUxaoCyvtwoPeLbI1ksFyLxi/CazZpWY=";
      version = "3.0.1";
    };
    resolved = {
      kind = "builds";
      attr = "mcp-nixos";
      input = "nixpkgs";
    };
    retire = "auto";
    removal = ''
      Retired by the weekly run once
      `mcp-nixos` builds again at the revision nixpkgs is locked to.
      Deleting this entry is the whole removal; nothing else is fenced.
    '';
  };
  # END WORKAROUND(pin-mcp-nixos)
}
