{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.desktop;

  # Carried over from the settings.ini this replaces, minus the Plasma-era
  # leftovers in it (colorreload-gtk-module, the ocean sound theme, and an
  # xft-dpi that only restated 96).
  gtkExtraConfig = {
    gtk-application-prefer-dark-theme = true;
    gtk-decoration-layout = "icon:minimize,maximize,close";
  };
in
{
  options.cyberfighter.features.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Desktop applications";
    };

    firefox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Firefox browser";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.firefox;
        description = "Firefox package to use";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra desktop packages to install";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.firefox.enable) {
      programs.firefox = {
        enable = true;
        package = lib.mkDefault cfg.firefox.package;
      };
    })

    (lib.mkIf cfg.enable {
      nixpkgs.config.allowUnfree = true;

      home.packages =
        with pkgs;
        [
          bottles
          super-productivity
          vivaldi
          qbittorrent
          (catppuccin-kde.override {
            flavour = [ "frappe" ];
            accents = [ "blue" ];
            winDecStyles = [ "modern" ];
          })
        ]
        ++ cfg.extraPackages;

      # Home Manager's gtk module was never enabled, so gtk.iconTheme — set
      # to Papirus-Dark by the catppuccin module — installed nothing and
      # wrote nothing. ~/.config/gtk-*/settings.ini stayed a stale Plasma-era
      # file naming breeze-dark, a theme this host does not have, so every
      # icon looked up by name failed: that is why tray items publishing an
      # IconName (blueman's "blueman-tray") drew a placeholder square.
      gtk = {
        enable = true;

        font = {
          name = "Noto Sans";
          size = 10;
        };

        gtk3.extraConfig = gtkExtraConfig;
        gtk4.extraConfig = gtkExtraConfig;
      };

      # The stale file named Catppuccin-Frappe-Blue-Cursors, which the 2.0.0
      # package renamed to lowercase, so the cursor theme was broken the same
      # way the icon theme was. pointerCursor rather than gtk.cursorTheme:
      # it also writes ~/.icons/default and exports XCURSOR_*, which is what
      # Wayland clients actually read.
      home.pointerCursor = {
        enable = true;
        name = "catppuccin-frappe-blue-cursors";
        package = pkgs.catppuccin-cursors.frappeBlue;
        size = 24;
        gtk.enable = true;
      };

      # GTK4 and anything else reading gsettings went through dconf, which
      # held breeze-dark independently of settings.ini.
      dconf.settings."org/gnome/desktop/interface" = {
        icon-theme = config.gtk.iconTheme.name;
        cursor-theme = config.gtk.cursorTheme.name;
        color-scheme = "prefer-dark";
      };

      # Home Manager refuses to clobber the unmanaged files it is about to
      # take over; move them aside instead of failing the switch. Every file
      # the gtk module and pointerCursor write, since this host has
      # Plasma-era copies of most of them.
      home.activation.backupStaleGtkSettings = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        for f in \
          "$HOME/.gtkrc-2.0" \
          "${config.xdg.configHome}/gtk-3.0/settings.ini" \
          "${config.xdg.configHome}/gtk-3.0/gtk.css" \
          "${config.xdg.configHome}/gtk-4.0/settings.ini" \
          "${config.xdg.configHome}/gtk-4.0/gtk.css" \
          "$HOME/.icons/default/index.theme"; do
          if [ -f "$f" ] && [ ! -L "$f" ]; then
            run mv "$f" "$f.pre-hm-bak"
          fi
        done
      '';
    })
  ];
}
