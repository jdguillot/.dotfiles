{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.niri;
  styles = [
    "minimal"
    "rounded"
    "showcase"
  ];
  capitalize = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;

  # niri only spawns the chosen shell at session start, so a live swap has to
  # stop and start them by hand. Both shells ship their own kill subcommand.
  shellCommands = {
    noctalia = {
      label = "Noctalia";
      start = "noctalia-shell";
      stop = "noctalia-shell kill";
    };
    dank = {
      label = "DankMaterialShell";
      start = "dms run";
      stop = "dms kill";
    };
  };

  # Electron builds its tray once, early, and silently gives up if no
  # StatusNotifier host has registered yet -- it never retries. base.kdl used
  # to spawn the shell on the line above 1Password, so the shell always won
  # that race; splitting the shell into its own layer (included after
  # base.kdl) flipped the order and cost 1Password its tray icon. Wait for a
  # host rather than depending on spawn order again.
  spawnAfterTray = pkgs.writeShellApplication {
    name = "spawn-after-tray";
    runtimeInputs = [
      pkgs.glib
      pkgs.coreutils
    ];
    text = ''
      gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher || true

      # The watcher can exist before any host has registered, which is the
      # state Electron gives up on, so wait for the host too.
      tries=0
      while [ "$tries" -lt 100 ]; do
        registered=$(gdbus call --session \
          --dest org.kde.StatusNotifierWatcher \
          --object-path /StatusNotifierWatcher \
          --method org.freedesktop.DBus.Properties.Get \
          org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered 2>/dev/null || true)
        if [ "$registered" = "(<true>,)" ]; then
          break
        fi
        tries=$((tries + 1))
        sleep 0.1
      done

      exec "$@"
    '';
  };

  # Swap the style-current.kdl symlink and reload niri — no rebuild needed.
  styleScript = pkgs.writeShellApplication {
    name = "niri-style";
    text = ''
      styles_dir="$HOME/.config/niri/styles"
      current="$HOME/.config/niri/style-current.kdl"

      case "''${1:-list}" in
        list|-l|--list)
          echo "Usage: niri-style <name>"
          if [[ -L "$current" ]]; then
            echo "Current: $(basename "$(readlink "$current")" .kdl)"
          fi
          echo "Available styles:"
          for f in "$styles_dir"/*.kdl; do
            basename "$f" .kdl | sed 's/^/  /'
          done
          ;;
        *)
          style="$styles_dir/$1.kdl"
          if [[ ! -e "$style" ]]; then
            echo "Unknown style: $1 (try 'niri-style list')" >&2
            exit 1
          fi
          ln -sf "$style" "$current"
          niri msg action load-config-file || true
          echo "Switched niri style to '$1'."
          ;;
      esac
    '';
  };

  # Same symlink trick for the shell layer, plus the process handoff the
  # style switch doesn't need. The symlink persists, so the next login keeps
  # the choice until a session entry or another switch overrides it.
  shellScript = pkgs.writeShellApplication {
    name = "niri-shell";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      shells_dir="$HOME/.config/niri/shells"
      current="$HOME/.config/niri/shell-current.kdl"

      case "''${1:-list}" in
        list|-l|--list)
          echo "Usage: niri-shell <name>"
          if [[ -L "$current" ]]; then
            echo "Current: $(basename "$(readlink "$current")" .kdl)"
          fi
          echo "Available shells:"
          for f in "$shells_dir"/*.kdl; do
            basename "$f" .kdl | sed 's/^/  /'
          done
          ;;
        ${lib.concatMapStringsSep "|" (s: s) cfg.shells})
          ln -sfn "$shells_dir/$1.kdl" "$current"
          niri msg action load-config-file || true
          ${lib.concatMapStringsSep "\n    " (
            s: "${shellCommands.${s}.stop} >/dev/null 2>&1 || true"
          ) cfg.shells}
          case "$1" in
            ${lib.concatMapStringsSep "\n      " (
              s: "${s}) setsid --fork ${shellCommands.${s}.start} >/dev/null 2>&1 ;;"
            ) cfg.shells}
          esac
          echo "Switched niri shell to '$1'."
          ;;
        *)
          echo "Unknown shell: $1 (try 'niri-shell list')" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.cyberfighter.features.niri = {
    enable = lib.mkEnableOption "Niri compositor config";
    style = lib.mkOption {
      type = lib.types.enum styles;
      default = "rounded";
      description = ''
        Initial visual style variant for niri. Shared config lives in
        base.kdl; the active style is included at runtime from
        ~/.config/niri/style-current.kdl and can be switched without a
        rebuild via the niri-style command (or the launcher entries).
        - minimal: tight gaps, thin solid ring, no shadows (previous look)
        - rounded: rounded corners, shadows, gradient focus ring, snappy springs
        - showcase: bigger gaps, rainbow gradient, blur, translucent terminals
      '';
    };
    shells = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames shellCommands));
      default = builtins.attrNames shellCommands;
      description = ''
        Desktop shells installed alongside niri. Each one deploys its layer
        to ~/.config/niri/shells/<name>.kdl and can be selected at login
        (the "Niri (…)" greeter sessions) or swapped in place with
        `niri-shell <name>`. Trim the list on hosts that should not carry a
        second Quickshell closure. Each entry needs its own feature module
        enabled — features.noctalia or features.dank — which is what owns
        the packages; this option only deploys the niri-side layer.
      '';
    };
    shell = lib.mkOption {
      type = lib.types.enum (builtins.attrNames shellCommands);
      default = "noctalia";
      description = ''
        Shell seeded on first activation, i.e. the one a session gets before
        anything picks another. base.kdl holds the shell-agnostic core
        (window motions, window rules); the active shell's spawn plus its
        panel/media/lock binds are included after it from
        ~/.config/niri/shell-current.kdl, so shell binds win on conflict
        (niri binds are later-wins — the dank layer deliberately takes over
        Mod+V and Mod+Comma).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # This module deploys the layers; the packages behind them belong to the
    # shells' own feature modules.
    assertions = [
      {
        assertion = builtins.elem cfg.shell cfg.shells;
        message = "cyberfighter.features.niri.shell = \"${cfg.shell}\" is not in features.niri.shells.";
      }
      {
        assertion = builtins.elem "noctalia" cfg.shells -> config.cyberfighter.features.noctalia.enable;
        message = "features.niri.shells includes \"noctalia\" but features.noctalia.enable is false.";
      }
      {
        assertion = builtins.elem "dank" cfg.shells -> config.cyberfighter.features.dank.enable;
        message = "features.niri.shells includes \"dank\" but features.dank.enable is false.";
      }
    ];

    # niri the compositor is installed at the NixOS level (desktop.environment
    # = "niri"); this module just deploys the user config.
    xdg.configFile = {
      "niri/config.kdl".text = ''
        ${builtins.readFile ./base.kdl}
        // Active visual style, switched at runtime via `niri-style <name>`.
        include "~/.config/niri/style-current.kdl" optional=true
        // Active desktop shell (spawn + panel/media binds), switched at
        // runtime via `niri-shell <name>` or the greeter session entries.
        // Last, so a shell that manages niri settings itself (dank pulls in
        // DMS's generated dms/*.kdl) wins over the style's geometry.
        include "~/.config/niri/shell-current.kdl" optional=true
      '';
    }
    // builtins.listToAttrs (
      map (s: {
        name = "niri/styles/${s}.kdl";
        value.source = ./styles + "/${s}.kdl";
      }) styles
    )
    // builtins.listToAttrs (
      map (s: {
        name = "niri/shells/${s}.kdl";
        value.source = ./shells + "/${s}.kdl";
      }) cfg.shells
    );

    home.packages = [
      styleScript
      shellScript
      spawnAfterTray
    ];

    # Seed both symlinks on first activation; runtime choice wins after.
    home.activation.niriStyleDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current="$HOME/.config/niri/style-current.kdl"
      if [ ! -e "$current" ]; then
        run ln -sf "$HOME/.config/niri/styles/${cfg.style}.kdl" "$current"
      fi
    '';

    home.activation.niriShellDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current="$HOME/.config/niri/shell-current.kdl"
      if [ ! -e "$current" ]; then
        run ln -sfn "$HOME/.config/niri/shells/${cfg.shell}.kdl" "$current"
      fi
    '';

    # Make styles and shells switchable from the launcher (Mod+Space).
    xdg.desktopEntries =
      builtins.listToAttrs (
        map (s: {
          name = "niri-style-${s}";
          value = {
            name = "Niri Style: ${capitalize s}";
            comment = "Switch niri visual style to ${s}";
            exec = "niri-style ${s}";
            icon = "preferences-desktop-theme";
            terminal = false;
            categories = [ "Settings" ];
          };
        }) styles
      )
      // builtins.listToAttrs (
        map (s: {
          name = "niri-shell-${s}";
          value = {
            name = "Niri Shell: ${shellCommands.${s}.label}";
            comment = "Switch the niri desktop shell to ${s}";
            exec = "niri-shell ${s}";
            icon = "preferences-desktop";
            terminal = false;
            categories = [ "Settings" ];
          };
        }) cfg.shells
      );
  };
}
