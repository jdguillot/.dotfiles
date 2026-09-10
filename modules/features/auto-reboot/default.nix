# auto-reboot -- take the pending reboot a kernel bump leaves behind.
#
# `switch` applies a kernel bump in full except for the kernel itself, which
# waits for a reboot (see .github/scripts/boot-requirement.sh). Unattended
# deploys mean that pending reboot otherwise accumulates silently until
# something notices. This closes that loop on a schedule, warning whoever is
# logged in first and letting them push it back.
#
# Deliberately not here: any check that the host came back. A machine cannot
# report its own failure to return, so that belongs to something watching
# from outside, not to this module.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.autoReboot;

  stateDir = "auto-reboot";
  shared = {
    STATE = "/var/lib/${stateDir}";
    SHUTDOWN = lib.getExe' config.systemd.package "shutdown";
  };

  autoReboot = pkgs.replaceVarsWith {
    name = "auto-reboot";
    src = ./auto-reboot.sh;
    isExecutable = true;
    replacements = shared // {
      WARNING = toString cfg.warningMinutes;
      READLINK = lib.getExe' pkgs.coreutils "readlink";
      LOGINCTL = lib.getExe' config.systemd.package "loginctl";
      RUNUSER = lib.getExe' pkgs.util-linux "runuser";
      NOTIFYSEND = lib.getExe' pkgs.libnotify "notify-send";
    };
  };

  rebootPostpone = pkgs.replaceVarsWith {
    name = "reboot-postpone";
    src = ./reboot-postpone.sh;
    dir = "bin";
    isExecutable = true;
    replacements = shared // {
      DEFAULT = cfg.postpone.duration;
      MAX = toString cfg.postpone.max;
    };
  };
in
{
  options.cyberfighter.features.autoReboot = {
    enable = lib.mkEnableOption "taking the pending reboot after a kernel bump";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "Sun *-*-* 04:00:00";
      example = "*-*-* 04:00:00";
      description = ''
        systemd `OnCalendar` expression for when to consider rebooting.
        Nothing happens unless a reboot is actually pending, so a daily
        schedule only fires on the days a kernel moved.
      '';
    };

    randomizedDelay = lib.mkOption {
      type = lib.types.str;
      default = "15m";
      description = ''
        `RandomizedDelaySec`. Keeps hosts sharing a schedule from rebooting
        in lockstep, which for VMs on one Proxmox box is a thundering herd.
      '';
    };

    warningMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = ''
        Minutes between warning logged-in users and the reboot. With nobody
        logged in the reboot goes at +1 instead and no warning is sent.
      '';
    };

    postpone = {
      duration = lib.mkOption {
        type = lib.types.str;
        default = "4h";
        description = "Default `reboot-postpone` delay; anything `date -d` parses.";
      };

      max = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = ''
          How many times in a row the reboot may be deferred. The count
          resets when a reboot actually happens.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.kernel.enable;
        message = "cyberfighter.features.autoReboot: this host boots someone else's kernel (boot.kernel.enable = false), so it has no pending reboot to take.";
      }
    ];

    systemd.services.auto-reboot = {
      description = "Reboot if a generation is waiting for one";
      # date/cat/rm are called bare in the script; a systemd unit gets none
      # of the login PATH.
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = autoReboot;
        StateDirectory = stateDir;
      };
    };

    systemd.timers.auto-reboot = {
      description = "Scheduled check for a pending reboot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = cfg.randomizedDelay;
        # A missed window must not turn into a reboot at the next boot, which
        # is the one moment the machine demonstrably does not need one.
        Persistent = false;
      };
    };

    environment.systemPackages = [ rebootPostpone ];
  };
}
