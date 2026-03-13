{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.cyberfighter.features.onepassword;
  op-wsl = pkgs.writeShellScriptBin "op" (builtins.readFile ./op-wsl.sh);
in
{
  # environment.systemPackages = [ op-wsl ];
  options.cyberfighter.features.onepassword = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 1Password CLI";
    };
  };

  config = lib.mkIf cfg.enable {
    programs._1password = {
      enable = true;
    };
  };
}
