{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cyberfighter.features.tools.cargoSweep;
in
{
  options.cyberfighter.features.tools.cargoSweep = {
    enable = lib.mkEnableOption "scheduled cargo-sweep of stale Rust build output";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${config.home.homeDirectory}/projects" ];
      defaultText = lib.literalExpression ''[ "''${config.home.homeDirectory}/projects" ]'';
      description = "Directories searched recursively for Cargo target folders.";
    };

    days = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Remove build artifacts not used in this many days.";
    };

    frequency = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd OnCalendar expression for the sweep.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.cargo-sweep ];

    systemd.user.services.cargo-sweep = {
      Unit.Description = "Remove stale Cargo build artifacts";
      Service = {
        Type = "oneshot";
        # --time, not --installed: toolchains come from Nix, so rustup has none to report.
        ExecStart = map (
          path: "${lib.getExe pkgs.cargo-sweep} sweep --recursive --time ${toString cfg.days} ${path}"
        ) cfg.paths;
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers.cargo-sweep = {
      Unit.Description = "Scheduled cargo-sweep";
      Timer = {
        OnCalendar = cfg.frequency;
        # Catch up on runs missed while the machine (or WSL VM) was off.
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
