# ComfyUI itself, as a docker compose project -- deliberately not packaged
# in the flake: custom nodes pip-install at runtime (impossible in a
# read-only Nix python env), and a bad release must never block a rebuild.
#
# Same pattern as the traefik module: native compose.yaml with @NAME@
# placeholders rendered from the options below; the module deploys it to
# /etc/comfyui, owns the bind-mount dirs, and runs a boot-time oneshot.
# Model downloads are ./default.nix; the OpenAI images shim is ./openai-api.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.comfyui.server;
  traefikCfg = config.cyberfighter.features.traefik;

  composeYaml = pkgs.replaceVars ./compose.yaml {
    BIND = cfg.bind;
    PORT = toString cfg.port;
    CLI_ARGS = cfg.cliArgs;
    DATA_DIR = cfg.dataDir;
    USER_DATA_DIR = cfg.userDataDir;
    NETWORK = traefikCfg.network;
  };

  # Rendered into compose.yaml volume lines; keep yaml structure out.
  validDir = d: builtins.match "/[A-Za-z0-9._/-]*[A-Za-z0-9._-]" d != null;
in
{
  options.cyberfighter.features.ai.comfyui.server = {
    enable = lib.mkEnableOption "ComfyUI (docker compose)";

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address docker publishes the port on, for host-local clients (the
        openai-api shim). ComfyUI has NO authentication and can run arbitrary
        workflows, so network access goes through the basic-authed traefik
        route at `publicHost` -- docker's DNAT bypasses networking.firewall,
        making this line the rest of the access-control story.
      '';
    };

    publicHost = lib.mkOption {
      type = lib.types.str;
      example = "comfyui.example.com";
      description = ''
        Hostname traefik routes to the container, behind chain-basic-auth
        (the shared htpasswd). Rendered into the compose labels.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8188;
      description = "Host port ComfyUI is published on (the container side stays 8188).";
    };

    cliArgs = lib.mkOption {
      type = lib.types.str;
      default = "--fast";
      description = "Value of the image's CLI_ARGS environment variable, passed to ComfyUI's argv.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/comfyui";
      description = ''
        Root of the machine-recreatable state: cache/, nodes/ and models/
        bind mounts. Created by tmpfiles owned by `user`, with CoW disabled
        (checkpoints fragment badly on btrfs otherwise).
      '';
    };

    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.cyberfighter.system.username}/comfyui";
      defaultText = lib.literalExpression ''"/home/''${config.cyberfighter.system.username}/comfyui"'';
      description = ''
        Root of the user documents: input/, output/, user-profile/ and
        user-scripts/ bind mounts. Under $HOME by default so home snapshots
        cover it -- workflows and outputs are the only ComfyUI data a
        rebuild cannot recreate.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.cyberfighter.system.username;
      defaultText = lib.literalExpression "config.cyberfighter.system.username";
      description = "Owner of the bind-mount directories, so models and outputs need no sudo.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group owning the bind-mount directories.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # compose.yaml requests the GPU via CDI unconditionally.
        assertion = config.cyberfighter.features.graphics.nvidia.containerToolkit;
        message = "cyberfighter.features.ai.comfyui.server needs cyberfighter.features.graphics.nvidia.containerToolkit = true (the compose file requests the GPU via CDI).";
      }
      {
        # The route, the network and the auth middleware all come from traefik.
        assertion = traefikCfg.enable;
        message = "cyberfighter.features.ai.comfyui.server needs cyberfighter.features.traefik.enable = true.";
      }
      {
        assertion = builtins.match "[0-9.]+" cfg.bind != null;
        message = "cyberfighter.features.ai.comfyui.server.bind must be an IPv4 address.";
      }
      {
        assertion = validDir cfg.dataDir && validDir cfg.userDataDir;
        message = "cyberfighter.features.ai.comfyui.server.dataDir and userDataDir must be absolute paths without a trailing slash (letters, digits, '.', '_', '-', '/').";
      }
      {
        # Rendered inside the double quotes of `CLI_ARGS: "..."`.
        assertion = !lib.hasInfix "\"" cfg.cliArgs && !lib.hasInfix "\\" cfg.cliArgs;
        message = "cyberfighter.features.ai.comfyui.server.cliArgs must not contain quotes or backslashes.";
      }
    ];

    # Bind-mount targets, user-owned so no sudo is needed. `h +C`: CoW
    # fragments multi-gigabyte checkpoints. `Z` re-chowns what the container
    # creates as root; mode `-` keeps .safetensors non-executable.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "h ${cfg.dataDir} - - - - +C"
      "d ${cfg.dataDir}/cache 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/nodes 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/models 0755 ${cfg.user} ${cfg.group} -"
      "Z ${cfg.dataDir}/models/models - ${cfg.user} ${cfg.group} -"

      "d ${cfg.userDataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.userDataDir}/input 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.userDataDir}/output 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.userDataDir}/user-profile 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.userDataDir}/user-scripts 0755 ${cfg.user} ${cfg.group} -"
      "Z ${cfg.userDataDir} - ${cfg.user} ${cfg.group} -"
    ];

    environment.etc."comfyui/compose.yaml".source = composeYaml;

    # chain-basic-auth: traefik's htpasswd gate is the only login in front
    # of arbitrary workflow execution.
    cyberfighter.features.traefik.routes.comfyui = {
      host = cfg.publicHost;
      port = 8188;
    };

    # Boot-start only. Everything else (logs, pull, exec) is `comfyui-compose`.
    cyberfighter.features.compose.projects.comfyui = {
      description = "ComfyUI (docker compose)";
      files = [
        "/etc/comfyui/compose.yaml"
        "${traefikCfg.routeLabelFiles.comfyui}"
      ];
      networks = [ traefikCfg.network ];
      # Pulling a multi-gigabyte CUDA image on a cold start takes a while.
      timeout = "30min";
      restartTriggers = [ composeYaml ];
    };
  };
}
