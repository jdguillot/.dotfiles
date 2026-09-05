{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.dank;
  plugins = cfg.plugins;

  # Plugin repos are pinned in npins/sources.json, not flake.lock; move one
  # forward with `npins update <name>` from the repo root.
  sources = import ../../../../npins;
  dmsPlugins = sources.dms-plugins;

  # Attribute names are the plugin's own `id` from its plugin.json. DMS keys
  # both the directory under plugins/ and the entry in plugin_settings.json
  # on that id, so a mismatch installs a plugin that nothing can enable.
  catalog = {
    aiOverviewControl = sources.dms-plugin-ai-overview;
    dankKDEConnect = "${dmsPlugins}/DankKDEConnect";
    dankLauncherKeys = "${dmsPlugins}/DankLauncherKeys";
    dankscale = sources.dms-plugin-dankscale;
    developerUtilities = sources.dms-plugin-developer-utilities;
    homeAssistantMonitor = sources.dms-plugin-hass;
    nixMonitor = sources.dms-plugin-nix-monitor;
    nixPackageRunner = sources.dms-plugin-nix-package-runner;
    quickCapture = sources.dms-plugin-quick-capture;
    tailscale = sources.dms-plugin-tailscale;
    typingSounds = sources.dms-plugin-typing-sounds;
    wallpaperCarousel = sources.dms-plugin-wallpaper-carousel;
  };

  selected = lib.filterAttrs (name: _: !(lib.elem name plugins.exclude)) (catalog // plugins.extra);

  pluginDir = "${config.xdg.configHome}/DankMaterialShell/plugins";
  pluginSettings = "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json";
  lockFile = "${config.xdg.configHome}/DankMaterialShell/plugins.lock.json";

  managed = builtins.toJSON (lib.attrNames selected);

  # Every managed plugin starts enabled; whatever the live file already says
  # wins, so a GUI toggle or a plugin's own settings survive a switch.
  defaults = builtins.toJSON (lib.mapAttrs (_: _: { enabled = true; }) selected);

  # DMS's plugin manager cloned these into plugins/<id>, or symlinked them
  # out of plugins/.repos for the monorepo ones. Home Manager refuses to
  # replace paths it does not already own, so hand them over once -- and
  # drop the matching lockfile entries, or the GUI updater keeps trying to
  # git-pull a read-only store path.
  takeoverScript = pkgs.writeShellApplication {
    name = "dank-plugins-takeover";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      for name in $(jq -r '.[]' <<<'${managed}'); do
        target="${pluginDir}/$name"
        [ -e "$target" ] || [ -L "$target" ] || continue
        case "$(readlink -f "$target")" in
          /nix/store/*) continue ;;
        esac
        mv "$target" "$target.pre-nix-bak"
        rm -f "${pluginDir}/$name.meta"
      done

      [ -f "${lockFile}" ] || exit 0
      jq --argjson managed '${managed}' \
        '.plugins |= with_entries(select(.key as $k | $managed | index($k) | not))' \
        "${lockFile}" > "${lockFile}.tmp"
      mv "${lockFile}.tmp" "${lockFile}"
    '';
  };

  enableScript = pkgs.writeShellApplication {
    name = "dank-plugins-enable";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      mkdir -p "$(dirname "${pluginSettings}")"
      [ -f "${pluginSettings}" ] || echo '{}' > "${pluginSettings}"
      jq --argjson defaults '${defaults}' '$defaults * .' \
        "${pluginSettings}" > "${pluginSettings}.tmp"
      mv "${pluginSettings}.tmp" "${pluginSettings}"
    '';
  };
in
{
  options.cyberfighter.features.dank.plugins = {
    enable = lib.mkEnableOption "the pinned DMS plugin set" // {
      default = true;
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "wallpaperCarousel" ];
      description = "Catalog entries to leave out, by plugin id.";
    };

    extra = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
      default = { };
      example = lib.literalExpression ''{ myPlugin = "''${sources.my-plugin}"; }'';
      description = "Extra plugins (plugin id → source directory), merged over the catalog.";
    };
  };

  config = lib.mkIf (cfg.enable && plugins.enable) {
    # Deploys ~/.config/DankMaterialShell/plugins/<id> as a store symlink per
    # plugin. plugin_settings.json is deliberately left unmanaged: DMS turns
    # it into a read-only symlink as soon as any plugin declares `settings`,
    # and it is also where plugins keep API tokens, which have no business
    # in a public repo. Enablement is seeded on activation instead.
    programs.dank-material-shell.plugins = lib.mapAttrs (_: src: { inherit src; }) selected;

    home.activation = {
      dankPluginsTakeover = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        run ${lib.getExe takeoverScript}
      '';

      dankPluginsEnable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe enableScript}
      '';
    };
  };
}
