{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.desktop;

  # Compositors dms-greeter can run itself, intersected with what this
  # module offers as `environment`.
  dmsGreeterCompositors = [
    "niri"
    "hyprland"
  ];

  # Desktop shells offered as separate niri sessions at the greeter. The
  # layers themselves are deployed by the Home Manager niri module
  # (cyberfighter.features.niri.shells) — these entries only pick one.
  niriShells = {
    noctalia = "Noctalia";
    dank = "DankMaterialShell";
  };

  # Point shell-current.kdl at the requested layer, then hand off to the
  # normal session. Leaves the symlink alone if the user's home doesn't ship
  # that layer, so a trimmed features.niri.shells still logs in.
  niriShellSession = pkgs.writeShellApplication {
    name = "niri-shell-session";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      layer="$HOME/.config/niri/shells/''${1:?usage: niri-shell-session <shell>}.kdl"
      if [ -e "$layer" ]; then
        ln -sfn "$layer" "$HOME/.config/niri/shell-current.kdl"
      fi
      exec ${config.programs.niri.package}/bin/niri-session
    '';
  };

  niriShellSessionEntry =
    name: label:
    pkgs.writeTextFile {
      name = "niri-${name}-session";
      destination = "/share/wayland-sessions/niri-${name}.desktop";
      text = ''
        [Desktop Entry]
        Name=Niri (${label})
        Comment=Scrollable-tiling Wayland compositor with the ${label} desktop shell
        Exec=${niriShellSession}/bin/niri-shell-session ${name}
        Type=Application
        DesktopNames=niri
      '';
      passthru.providedSessions = [ "niri-${name}" ];
    };
in
{
  options.cyberfighter.features.desktop = {
    enable = lib.mkEnableOption "Desktop environment support";

    environment = lib.mkOption {
      type = lib.types.enum [
        "plasma6"
        "plasma5"
        "gnome"
        "hyprland"
        "niri"
        "none"
      ];
      default = "plasma6";
      description = "Desktop environment to use";
    };

    displayManager = lib.mkOption {
      type = lib.types.enum [
        "sddm"
        "gdm"
        "greetd"
        "none"
      ];
      default = "sddm";
      description = "Display manager to use";
    };

    greeter = lib.mkOption {
      type = lib.types.enum [
        "dms"
        "tuigreet"
        "regreet"
      ];
      default = "dms";
      description = ''
        Greeter to use when displayManager = "greetd".
        - dms: the DankMaterialShell greeter, which mirrors the primary
          user's live DMS theme, wallpaper and settings
        - regreet: GTK greeter themed by hand (see regreet/)
        - tuigreet: text greeter, no compositor needed
      '';
    };

    firefox = lib.mkEnableOption "Firefox browser";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };

        environment.systemPackages = with pkgs; [
          kitty
          wofi
        ];

        # Both are optional dependencies that desktop shells probe over
        # D-Bus: accountsservice for the user avatar and account details,
        # power-profiles-daemon for the performance/balanced/saver switch
        # (DMS's power OSD is dead without it). mkDefault because
        # power-profiles-daemon and TLP cannot both be enabled.
        services.accounts-daemon.enable = lib.mkDefault true;
        services.power-profiles-daemon.enable = lib.mkDefault true;
      }

      (lib.mkIf (cfg.displayManager == "sddm") {
        services.displayManager.sddm.enable = true;
        security.pam.services.sddm.enableKwallet = lib.mkDefault true;
      })

      (lib.mkIf (cfg.displayManager == "gdm") {
        services.displayManager.gdm.enable = true;
        # services.displayManager.gdm.wayland = true;
      })

      (lib.mkIf (cfg.displayManager == "greetd" && cfg.greeter == "dms") {
        # dms-greeter runs its own compositor and pulls the look from the
        # primary user's live DMS config, so it tracks the desktop instead of
        # being themed separately. greetd itself is enabled by its module.
        services.greetd.settings.default_session.user = "greeter";

        assertions = [
          {
            assertion = builtins.elem cfg.environment dmsGreeterCompositors;
            message = "features.desktop.greeter = \"dms\" needs environment to be one of ${lib.concatStringsSep ", " dmsGreeterCompositors}, not \"${cfg.environment}\".";
          }
        ];

        programs.dms-greeter = {
          enable = true;
          # Falls back so the assertion above is what fails, not the enum.
          compositor.name =
            if builtins.elem cfg.environment dmsGreeterCompositors then cfg.environment else "niri";
          configHome = "/home/${config.cyberfighter.system.username}";
        };
      })

      (lib.mkIf (cfg.displayManager == "greetd" && cfg.greeter == "tuigreet") {
        services.greetd = {
          enable = true;
          settings.default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd ${cfg.environment}-session";
            user = "greeter";
          };
        };
      })

      (lib.mkIf (cfg.displayManager == "greetd" && cfg.greeter == "regreet") (
        let
          # In the store because the greeter user cannot read $HOME; switch
          # by changing filename + sha256.
          wallpaper = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/jdguillot/walls-catppuccin-mocha/7bfdf10d16ad3a689f9f0cf3a0930da3d1a245a8/dark-waves.jpg";
            sha256 = "0jillya220x4713wmn1vdspm46wvij2jnp8fib2sfbz42vddvb5k";
          };
        in
        {
          # Enables greetd and runs ReGreet inside cage; sessions come from
          # the registered wayland-sessions files, so no --cmd. GStreamer
          # plugins are baked into pkgs.regreet since nixpkgs #530302.
          services.displayManager.regreet = {
            enable = true;

            # Catppuccin Frappé + Lavender GTK theme.
            theme = {
              package = pkgs.catppuccin-gtk.override {
                accents = [ "lavender" ];
                variant = "frappe";
                size = "standard";
              };
              name = "catppuccin-frappe-lavender-standard";
            };

            # Native regreet.toml pulled in as-is; only the dynamic store
            # paths ([background].path) and dark-theme flag are injected.
            settings = lib.recursiveUpdate (lib.importTOML ./regreet/regreet.toml) {
              background = {
                path = "${wallpaper}";
                fit = "Cover";
              };
              GTK.application_prefer_dark_theme = true;
            };

            # Native CSS for Catppuccin accents on top of the GTK theme.
            extraCss = ./regreet/catppuccin-frappe.css;
          };

          # Software renderer: avoids GL-under-cage quirks on this iGPU; a
          # safe default, not a fix.
          systemd.services.greetd.environment.GSK_RENDERER = "cairo";
        }
      ))

      (lib.mkIf (cfg.environment == "plasma6") {
        services.desktopManager.plasma6.enable = true;
        environment.systemPackages = with pkgs; [
          kdePackages.kate
          kdePackages.konsole
        ];
      })

      (lib.mkIf (cfg.environment == "plasma5") {
        services.xserver.desktopManager.plasma5.enable = true;
      })

      (lib.mkIf (cfg.environment == "gnome") {
        services.xserver.desktopManager.gnome.enable = true;
      })

      (lib.mkIf (cfg.environment == "hyprland") {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
        };
      })

      (lib.mkIf (cfg.environment == "niri") {
        programs.niri = {
          enable = true;
        };
        services.upower.enable = true;
        services.udisks2.enable = true;
        # Note: noctalia-shell is now configured via home-manager, not NixOS
        environment.systemPackages = with pkgs; [
          mako
          quickshell
          nemo
          xwayland-satellite
        ];

        # One greeter entry per desktop shell, on top of the plain "Niri"
        # session that programs.niri registers (which keeps whatever shell
        # was last selected).
        services.displayManager.sessionPackages = lib.mapAttrsToList niriShellSessionEntry niriShells;
      })

      (lib.mkIf cfg.firefox {
        programs.firefox.enable = true;
      })
    ]
  );
}
