# Disk layout for ryzn-server: 1TB SSD (hot) + 1TB HDD (bulk).
#
# DANGER: two of the four drives belong to Windows, and disko wipes whatever
# it is pointed at -- devices MUST be /dev/disk/by-id/* (enumeration order is
# not stable across boots). Find them:
#   ls -l /dev/disk/by-id/ | grep -v -- '-part'
#
# Two separate btrfs filesystems, not one pool: btrfs has no SSD/HDD tiering.
let
  # Mount options are per-superblock (first mount wins), so every subvolume
  # on a disk shares one list; exceptions are chattr'd in configuration.nix.
  ssdOpts = [
    "compress=zstd:1" # cheap; NVMe is fast enough that heavier levels only cost CPU
    "noatime"
    "ssd"
    "discard=async"
  ];

  hddOpts = [
    "compress=zstd:3" # HDD is I/O bound, so spend more CPU to move fewer bytes
    "noatime"
  ];
in
{
  disko.devices = {
    disk = {
      # ---------------------------------------------------------------- SSD
      ssd = {
        type = "disk";
        # replace with the by-id path of the 1TB SSD
        device = "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S3Z8NY0M440002F";
        content = {
          type = "gpt";
          partitions = {
            # 1G: lanzaboote stores a full UKI per generation.
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            nixos = {
              size = "100%";
              name = "nixos";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "nixos"
                ];
                subvolumes = {
                  "/rootfs" = {
                    mountpoint = "/";
                    mountOptions = ssdOpts;
                  };

                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ssdOpts;
                  };

                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = ssdOpts;
                  };

                  # Kept out of / so log churn does not bloat root snapshots.
                  "/var-log" = {
                    mountpoint = "/var/log";
                    mountOptions = ssdOpts;
                  };

                  # overlay2 fragments under CoW; chattr +C in configuration.nix.
                  "/var-lib-docker" = {
                    mountpoint = "/var/lib/docker";
                    mountOptions = ssdOpts;
                  };

                  # Model weights: load time is paid on every session.
                  "/models" = {
                    mountpoint = "/var/lib/models";
                    mountOptions = ssdOpts;
                  };

                  # disko creates this nodatacow, as btrfs swapfiles require.
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "16G";
                  };
                };
              };
            };
          };
        };
      };

      # ---------------------------------------------------------------- HDD
      hdd = {
        type = "disk";
        # replace with the by-id path of the 1TB HDD
        device = "/dev/disk/by-id/ata-WDC_WD10EZEX-60ZF5A0_WD-WMC1S1828541";
        content = {
          type = "gpt";
          partitions = {
            bulk = {
              size = "100%";
              name = "bulk";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "-L"
                  "bulk"
                ];
                subvolumes = {
                  # The Steam library (Settings -> Storage -> Add Drive);
                  # HDD load times are the accepted trade.
                  "/games" = {
                    mountpoint = "/mnt/bulk/games";
                    mountOptions = hddOpts;
                  };

                  # Datasets, media, anything large and cold.
                  "/data" = {
                    mountpoint = "/mnt/bulk/data";
                    mountOptions = hddOpts;
                  };

                  # btrbk send target for the SSD subvolumes.
                  "/snapshots" = {
                    mountpoint = "/mnt/bulk/snapshots";
                    mountOptions = hddOpts;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
