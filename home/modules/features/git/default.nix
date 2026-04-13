{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.git;
in
{
  imports = [
    ./personal.nix
    ./work.nix
  ];

  options.cyberfighter.features.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Git configuration";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Git settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      signing.format = null; # This was changed in later version of HM and because my stateVersion i need this
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        pager = {
          diff = "delta";
          log = "delta";
          reflog = "delta";
          show = "delta";
        };
        status = {
          branch = true;
          showStash = true;
          showUntrackedFiles = "all";
        };
        diff = {
          tool = "nvimdiff";
          context = 3;
          renames = "copies";
          interHunkContext = 10;
        };
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
        delta = {
          features = "catppuccin-frappe";
          navigate = true;
          side-by-side = true;
          line-numbers = true;
          dark = true;
        };
      }
      // cfg.extraSettings;
    };
  };
}
