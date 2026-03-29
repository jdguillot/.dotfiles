{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.cyberfighter.features.onepassword;
  op-wsl = pkgs.writeShellScriptBin "op" (builtins.readFile ./op-wsl.sh);
  inherit (config.cyberfighter) profile;
in
{
  options.cyberfighter.features.onepassword = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 1Password CLI";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && profile.enable != "wsl") {
      programs._1password = {
        enable = true;
      };
    })

    (lib.mkIf (cfg.enable && profile.enable == "wsl") { environment.systemPackages = [ op-wsl ]; })

  ];
}
