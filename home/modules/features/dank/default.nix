{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.cyberfighter.features.dank;
  dmsPkgs = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system};

  liveSettings = "${config.xdg.configHome}/DankMaterialShell/settings.json";
  trackedSettings = ./settings.json;
  hasTrackedSettings = builtins.pathExists trackedSettings;

  # DMS's Settings GUI is the editor; settings.json is what it edits. The
  # niri fragments under ~/.config/niri/dms/ are regenerated from it, so the
  # repo tracks this file and never the fragments. Deliberately not
  # session.json — that holds location, launcher history and other local
  # state that has no business in a public repo.
  captureScript = pkgs.writeShellApplication {
    name = "dank-capture";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      repo="${cfg.capture.repo}"
      target="$repo/${cfg.capture.target}"
      live="${liveSettings}"

      # Hosts without a checkout (deploy-rs targets) have nothing to mirror.
      [[ -d "$repo/.git" ]] || exit 0
      [[ -f "$live" ]] || exit 0

      mkdir -p "$(dirname "$target")"
      # Sorted keys: DMS writes in insertion order, which would otherwise
      # churn the diff on every save.
      if ! jq -S . "$live" > "$target.tmp"; then
        echo "dank-capture: $live is not valid JSON, leaving $target alone" >&2
        rm -f "$target.tmp"
        exit 1
      fi

      if [[ -f "$target" ]] && cmp -s "$target.tmp" "$target"; then
        rm -f "$target.tmp"
        echo "dank-capture: no change"
        exit 0
      fi

      mv "$target.tmp" "$target"
      echo "dank-capture: updated ${cfg.capture.target} — review and commit it."
    '';
  };
in
{
  options.cyberfighter.features.dank = {
    enable = lib.mkEnableOption "DankMaterialShell and its desktop suite";

    extraQtPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.kdePackages.qtwebsockets ]";
      description = ''
        Qt/QML modules that DMS plugins (bar widgets) need at runtime.
        Installing them into the profile is not enough — Quickshell only
        sees QML modules on the import path the `dms` wrapper pins, so these
        are folded in through upstream's `extraQtPackages` override. That
        rebuilds dms-shell locally, so the list stays empty by default.
      '';
    };

    apps = {
      monitor =
        lib.mkEnableOption "dgop, the system monitor behind DMS's CPU/memory widgets and process list"
        // {
          default = true;
        };
      search = lib.mkEnableOption "dsearch, the indexed filesystem search daemon";
      calendar = lib.mkEnableOption "dcal (DankCalendar), the calendar app and its CalDAV sync";
    };

    capture = {
      enable =
        lib.mkEnableOption "mirroring DMS settings back into the dotfiles checkout when they change"
        // {
          default = true;
        };

      repo = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.dotfiles";
        description = "Checkout to mirror settings into. Ignored when absent.";
      };

      target = lib.mkOption {
        type = lib.types.str;
        default = "home/modules/features/dank/settings.json";
        description = "Path within the checkout that receives the settings snapshot.";
      };

      watch = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Run dank-capture automatically when DMS saves its settings, via a
          systemd user path unit. It only writes the working tree — never
          commits — so changes show up in `git status` for review.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # niri spawns dms from its shell layer (shells/dank.kdl), so the systemd
    # unit stays off — enabling both double-spawns the shell.
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = false;
      enableSystemMonitoring = cfg.apps.monitor; # gates the Mod+M binding
      enableDynamicTheming = true; # matugen wallpaper theming
      package = lib.mkIf (cfg.extraQtPackages != [ ]) (
        dmsPkgs.dms-shell.override { inherit (cfg) extraQtPackages; }
      );
      # settings.json stays runtime-managed: setting it here would deploy a
      # read-only store symlink and the Settings GUI could no longer save.
      # It is seeded on activation and mirrored back by dank-capture instead.
    };

    # dgop is not pulled in by the DMS module itself, but the bar's cpuUsage
    # and memUsage widgets and the Mod+M process list all shell out to it.
    home.packages = [
      captureScript
    ]
    ++ lib.optional cfg.apps.monitor inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.dgop;

    programs.dsearch.enable = cfg.apps.search;

    programs.dank-calendar = lib.mkIf cfg.apps.calendar {
      enable = true;
      # The systemd unit only exists to pop reminders; the app runs on demand.
      systemd.enable = true;
    };

    # Give a fresh home the tracked settings; after that the GUI owns the file.
    home.activation.dankSettingsSeed = lib.mkIf hasTrackedSettings (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -e "${liveSettings}" ]; then
          run mkdir -p "$(dirname "${liveSettings}")"
          run install -m 0644 "${trackedSettings}" "${liveSettings}"
        fi
      ''
    );

    systemd.user = lib.mkIf (cfg.capture.enable && cfg.capture.watch) {
      paths.dank-capture = {
        Unit.Description = "Watch DMS settings for changes";
        Path.PathChanged = liveSettings;
        Install.WantedBy = [ "default.target" ];
      };

      services.dank-capture = {
        Unit.Description = "Mirror DMS settings into the dotfiles checkout";
        Service = {
          Type = "oneshot";
          # DMS rewrites the file on every toggle; settle first so a slider
          # drag produces one snapshot instead of a dozen.
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
          ExecStart = lib.getExe captureScript;
        };
      };
    };
  };
}
