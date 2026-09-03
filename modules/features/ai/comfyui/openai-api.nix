# OpenAI images API in front of ComfyUI: bridges POST /v1/images/generations
# to ComfyUI's POST /prompt via ./comfyui-openai-shim.py (stdlib-only, a
# native systemd unit -- stateless, and no second copy of the weights).
# Tradeoff: a graph is flattened to prompt-in/image-out; one workflow file
# per exposed model buys the expressiveness back.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.comfyui.openaiApi;

  # Bind wide only for containers; exposure scoped by per-bridge holes.
  listenHost = if cfg.exposeToContainers then "0.0.0.0" else cfg.listen;

  # Explicit interpreter rather than patchShebangs: the unit runs under
  # DynamicUser with no inherited PATH, so /usr/bin/env has nothing to find.
  shim = pkgs.runCommand "comfyui-openai-shim" { } ''
    mkdir -p $out/bin
    substitute ${./comfyui-openai-shim.py} $out/bin/comfyui-openai-shim \
      --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
    chmod +x $out/bin/comfyui-openai-shim
  '';

  workflowDir = pkgs.linkFarm "comfyui-openai-workflows" (
    lib.mapAttrsToList (name: path: {
      name = "${name}.json";
      inherit path;
    }) cfg.workflows
  );
in
{
  options.cyberfighter.features.ai.comfyui.openaiApi = {
    enable = lib.mkEnableOption "OpenAI images API in front of ComfyUI";

    comfyuiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8188";
      description = "ComfyUI root. Loopback -- the shim runs on the host, next to it.";
    };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address, when `exposeToContainers` is off.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7860;
      description = "Listen port. Serves /v1/models, /v1/images/generations and /health.";
    };

    workflows = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {
        flux1-schnell = ./workflows/flux1-schnell.json;
      };
      defaultText = lib.literalExpression "{ flux1-schnell = ./workflows/flux1-schnell.json; }";
      example = lib.literalExpression ''
        {
          flux1-schnell = ./workflows/flux1-schnell.json;
          flux2-klein = ./workflows/flux2-klein.json;
        }
      '';
      description = ''
        Exposed models, as name -> workflow file. The attribute name is the
        model id clients select; the file is a ComfyUI graph in **API format**
        ("Save (API Format)" in the web UI, not the editor format).

        Placeholders are substituted structurally after the JSON is parsed, so
        any input whose value is exactly one of these is replaced:

          "%PROMPT%"  "%NEGATIVE%"  "%SEED%"  "%WIDTH%"  "%HEIGHT%"  "%BATCH%"

        The workflow has to end in SaveImage -- that is what puts the result in
        ComfyUI's history for the shim to read back.

        The default drives `flux1-schnell-fp8.safetensors`, which carries its
        own CLIP and VAE, so it needs no other files. A GGUF stack needs its own
        workflow: separate UnetLoaderGGUF, DualCLIPLoader and VAELoader nodes.
      '';
    };

    freeAfterRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Call ComfyUI's POST /free after every run, releasing the checkpoint
        from VRAM.

        On by default because ComfyUI otherwise keeps it resident forever, and
        on a card it shares with `ai.ollama` that is not a cache, it is a leak:
        a 17GB Flux checkpoint left loaded means Ollama cannot load a 19GB
        model and its requests fail outright.

        The cost is a cold checkpoint read on the next image. Same trade as
        `ai.ollama.keepAlive`, and the same reasoning -- a box that also games
        and serves LLMs cannot let one runtime pin the GPU.

        Turn off only on a host where ComfyUI owns the card.
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = ''
        Seconds to wait for a run. Generous on purpose: the first request after
        a cold start pays the checkpoint load before it samples anything.
      '';
    };

    exposeToContainers = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind 0.0.0.0 and open `port` on every bridge registered in
        `cyberfighter.features.docker.containerBridges`, for containerised
        clients. Not `allowedTCPPorts` -- that would put an unauthenticated
        image generator on the LAN.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.workflows != { };
        message = "cyberfighter.features.ai.comfyui.openaiApi: `workflows` is empty, so no model would be served.";
      }
    ];

    systemd.services.comfyui-openai-shim = {
      description = "OpenAI images API for ComfyUI";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${shim}/bin/comfyui-openai-shim"
          "--listen ${listenHost}"
          "--port ${toString cfg.port}"
          "--comfyui ${cfg.comfyuiUrl}"
          "--workflows ${workflowDir}"
          "--timeout ${toString cfg.timeout}"
          (if cfg.freeAfterRun then "--free-after-run" else "--no-free-after-run")
        ];

        # Stateless translator: no user, no writable path, nothing to persist.
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallFilter = [ "@system-service" ];
      };
    };

    networking.firewall.interfaces = lib.mkIf cfg.exposeToContainers (
      lib.genAttrs config.cyberfighter.features.docker.containerBridges (_: {
        allowedTCPPorts = [ cfg.port ];
      })
    );
  };
}
