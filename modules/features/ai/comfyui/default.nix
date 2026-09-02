# ComfyUI model store -- declarative weights, like services.ollama.loadModels;
# the runtime itself is ./server.nix. Downloaded, not built: fetchurl would
# put 35G in the store, and fixed-output derivations cannot resume a 17G
# transfer that dies at 90%.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.comfyui;

  modelType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        example = "vae/flux2-vae.safetensors";
        description = "Destination relative to `modelsDir`, including the ComfyUI subdirectory.";
      };

      url = lib.mkOption {
        type = lib.types.str;
        description = ''
          Direct download URL. For Hugging Face this is the `/resolve/<rev>/`
          form, not the `/blob/` page.
        '';
      };

      sha256 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Hex sha256 of the file. Verified after download, before the file is
          moved into place. For Hugging Face this is the LFS oid, readable
          without downloading:

            curl -sX POST https://huggingface.co/api/models/<repo>/paths-info/main \
              -H 'Content-Type: application/json' -d '{"paths":["<path>"]}'
        '';
      };
    };
  };

  # Reject paths escaping modelsDir at eval time.
  badPaths = lib.filter (m: lib.hasPrefix "/" m.path || lib.hasInfix ".." m.path) cfg.models;

  escapedDir = lib.escapeShellArg cfg.modelsDir;

  syncLines = lib.concatMapStringsSep "\n" (
    m:
    "sync_one ${lib.escapeShellArg m.path} ${lib.escapeShellArg m.url} "
    + lib.escapeShellArg (if m.sha256 == null then "-" else m.sha256)
  ) cfg.models;

  loaderScript = pkgs.writeShellScript "comfyui-model-loader" ''
    set -uo pipefail

    failed=0
    token=""
    if [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/hf-token" ]; then
      token=$(cat "$CREDENTIALS_DIRECTORY/hf-token")
    fi

    sync_one() {
      local rel="$1" url="$2" want="$3"
      local dest=${escapedDir}/"$rel"

      if [ -e "$dest" ]; then
        echo "present  $rel"
        return 0
      fi

      mkdir -p "$(dirname "$dest")"

      # Only ever send the token to Hugging Face itself.
      local -a hdr=()
      case "$url" in
        https://huggingface.co/*)
          if [ -n "$token" ]; then hdr=(-H "Authorization: Bearer $token"); fi
          ;;
      esac

      # -C - resumes the .part file; no progress meter (journal noise).
      echo "fetching $rel"
      if ! curl -fL --no-progress-meter --retry 3 --retry-delay 5 -C - \
             "''${hdr[@]}" -o "$dest.part" "$url"; then
        # Keep the partial file: this is the case resume exists for.
        echo "FAILED   $rel: download error" >&2
        failed=1
        return 0
      fi

      if [ "$want" != "-" ]; then
        local got
        got=$(sha256sum "$dest.part" | cut -d' ' -f1)
        if [ "$got" != "$want" ]; then
          # Finished-but-wrong is corrupt, not truncated; resuming would
          # append to garbage.
          rm -f "$dest.part"
          echo "FAILED   $rel: sha256 mismatch (want $want, got $got)" >&2
          failed=1
          return 0
        fi
      fi

      mv "$dest.part" "$dest"
      echo "done     $rel"
    }

    ${syncLines}

    if [ "$failed" -ne 0 ]; then
      echo "one or more models failed; see above" >&2
      exit 123
    fi
  '';
in
{
  options.cyberfighter.features.ai.comfyui = {
    enable = lib.mkEnableOption "declarative ComfyUI model downloads";

    modelsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/comfyui/models/models";
      description = "ComfyUI models root -- the directory holding checkpoints/, vae/, and friends.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User the loader runs as. Must own `modelsDir`.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group the loader runs as.";
    };

    hfTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''config.sops.secrets."hf-token".path'';
      description = ''
        File holding a Hugging Face access token, for gated repos. Passed to
        the unit via `LoadCredential` and only ever sent to huggingface.co.
      '';
    };

    models = lib.mkOption {
      type = lib.types.listOf modelType;
      default = [ ];
      description = ''
        Models to keep present under `modelsDir`. Existing files are left
        alone, so ad-hoc downloads through ComfyUI Manager still work; only
        missing entries are fetched.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.models != [ ]) {
    assertions = [
      {
        assertion = badPaths == [ ];
        message = ''
          cyberfighter.features.ai.comfyui: these `path` values are absolute or
          contain "..", which would write outside modelsDir:

            ${lib.concatMapStringsSep "\n    " (m: m.path) badPaths}
        '';
      }
    ];

    systemd.services.comfyui-model-loader = {
      description = "Download declared ComfyUI models";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.curl
        pkgs.coreutils
      ];

      serviceConfig = {
        # exec, not oneshot: a first sync is tens of GB and would hold
        # `nixos-rebuild switch` open; progress goes to the journal.
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;

        # A dead URL or bad hash must not fail activation.
        SuccessExitStatus = [
          "0"
          "123"
        ];

        LoadCredential = lib.optional (cfg.hfTokenFile != null) "hf-token:${cfg.hfTokenFile}";
        ExecStart = "${loaderScript}";
      };
    };
  };
}
