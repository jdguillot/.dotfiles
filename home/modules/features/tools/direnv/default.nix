{
  lib,
  config,
  ...
}:
let
  cfg = config.cyberfighter.features.tools.direnv;
in
{
  options.cyberfighter.features.tools.direnv = {
    enable = lib.mkEnableOption "Dir Env Tool";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
