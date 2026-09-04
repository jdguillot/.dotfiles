{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.tmuxai;

  # sopsFile override (home sops only reads secrets_common.yaml); enable only
  # where the USER age key is a recipient -- an undecryptable file kills the
  # whole user unit. Same pattern as opencode's remoteProvider.
  secretsYaml = ../../../../../secrets/secrets.yaml;
  remoteReady =
    cfg.remoteProvider.enable
    && builtins.pathExists secretsYaml
    && config.cyberfighter.features.sops.enable;

  # tmuxai only expands env vars in config values (no file references or
  # command substitution), so the sops-held server URL is exported by a
  # wrapper instead of being written into config.yaml.
  tmuxaiWrapped = pkgs.writeShellScriptBin "tmuxai" ''
    if [ -z "''${OLLAMA_BASE_URL:-}" ]; then
      OLLAMA_BASE_URL="$(cat ${config.sops.secrets."opencode-ollama-base-url".path})"
      export OLLAMA_BASE_URL
    fi
    exec ${lib.getExe pkgs.tmuxai} "$@"
  '';

  # cobra's generator; upstream ships no completion files. Generated from the
  # unwrapped package so the wrapper never runs at build time.
  completions =
    pkgs.runCommand "tmuxai-completions"
      {
        nativeBuildInputs = [ pkgs.tmuxai ];
      }
      ''
        export HOME=$TMPDIR
        mkdir -p $out/share/bash-completion/completions \
                 $out/share/zsh/site-functions \
                 $out/share/fish/vendor_completions.d
        tmuxai completion bash > $out/share/bash-completion/completions/tmuxai
        tmuxai completion zsh > $out/share/zsh/site-functions/_tmuxai
        tmuxai completion fish > $out/share/fish/vendor_completions.d/tmuxai.fish
      '';
in
{
  options.cyberfighter.features.tools.tmuxai = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Enable TmuxAI, the in-tmux terminal assistant. Defaults to the host's dev trait.";
    };

    remoteProvider = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Export OLLAMA_BASE_URL from the opencode-ollama-base-url sops
          secret (the direct-Tailscale ollama URL, shared with opencode
          and crush -- tmuxai cannot send CF Access headers, so a tunneled
          endpoint would never work here) via a wrapper around the binary.
          Without it the variable must come from the environment. Only
          usable where the user age key is a recipient of
          secrets/secrets.yaml.
        '';
      };
    };

    models = {
      coder = lib.mkOption {
        type = lib.types.str;
        default = "qwen3.8:27b-q4_K_M";
        description = "Ollama model tag for the default `coder` entry; must exist on the server OLLAMA_BASE_URL points at.";
      };

      small = lib.mkOption {
        type = lib.types.str;
        default = "qwen3.5:4b-q4_K_M";
        description = "Ollama model tag for the `small` entry (switch with /model small).";
      };
    };

    contextSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 262144;
      description = ''
        tmuxai's max_context_size (squash threshold). Must not exceed the
        serving window on the Ollama server -- see the opencode module's
        ollama.contextLength for why a larger value stalls generation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (if remoteReady then tmuxaiWrapped else pkgs.tmuxai)
      completions
    ];

    # Native upstream format; @VARS@ are the only Nix-filled values.
    xdg.configFile."tmuxai/config.yaml".source = pkgs.replaceVars ./config.yaml {
      CODER_MODEL = cfg.models.coder;
      SMALL_MODEL = cfg.models.small;
      CONTEXT_SIZE = toString cfg.contextSize;
    };

    sops.secrets."opencode-ollama-base-url" = lib.mkIf remoteReady {
      sopsFile = secretsYaml;
    };
  };
}
