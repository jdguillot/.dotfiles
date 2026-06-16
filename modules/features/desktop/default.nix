{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.desktop;
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
        "tuigreet"
        "regreet"
      ];
      default = "tuigreet";
      description = "Greeter to use when displayManager = \"greetd\"";
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
      }

      (lib.mkIf (cfg.displayManager == "sddm") {
        services.displayManager.sddm.enable = true;
        security.pam.services.sddm.enableKwallet = lib.mkDefault true;
      })

      (lib.mkIf (cfg.displayManager == "gdm") {
        services.displayManager.gdm.enable = true;
        # services.displayManager.gdm.wayland = true;
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
          # Single wallpaper pulled from the same walls-catppuccin-mocha fork
          # used elsewhere, pinned by commit. Lives in the store (world
          # readable) because the greeter user cannot read $HOME. To switch
          # wallpaper: change the filename + sha256 (nix-prefetch-url <url>).
          wallpaper = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/jdguillot/walls-catppuccin-mocha/7bfdf10d16ad3a689f9f0cf3a0930da3d1a245a8/dark-waves.jpg";
            sha256 = "0jillya220x4713wmn1vdspm46wvij2jnp8fib2sfbz42vddvb5k";
          };
        in
        {
          # programs.regreet enables greetd and runs ReGreet inside cage.
          # ReGreet lists sessions from the registered wayland-sessions files
          # (niri.desktop is registered), so no --cmd is needed here.
          programs.regreet = {
            enable = true;

            # ReGreet 0.4.0 routes the [background] through GStreamer
            # (GstPlay/playbin3), but the nixpkgs package ships no GStreamer
            # plugins -> "playbin3 element not found" -> fatal GStreamer-Play-
            # ERROR -> SIGABRT -> greetd restart loop. Setting the plugin path
            # via env does NOT work because wrapGAppsHook4 overrides it; the fix
            # is to add GStreamer to buildInputs so the wrapper bakes the plugin
            # path in. Mirrors nixpkgs PR #530302; drop this override once it
            # lands in our nixpkgs pin.
            package = pkgs.regreet.overrideAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ (
                with pkgs.gst_all_1;
                [
                  gstreamer
                  gst-plugins-base
                  gst-plugins-good
                ]
              );
            });

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

          # GTK4 software renderer for the greeter -- backend-independent and
          # avoids any GL/Vulkan-under-cage renderer quirks on this iGPU. The
          # crash was GStreamer, not the renderer, so this is just a safe
          # default; drop it later if you want the GPU renderer.
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
      })

      (lib.mkIf cfg.firefox {
        programs.firefox.enable = true;
      })
    ]
  );
}
