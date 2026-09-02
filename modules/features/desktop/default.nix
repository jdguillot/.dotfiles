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
      })

      (lib.mkIf cfg.firefox {
        programs.firefox.enable = true;
      })
    ]
  );
}
