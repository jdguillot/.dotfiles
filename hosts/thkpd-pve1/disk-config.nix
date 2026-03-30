{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            root = {
              size = "200G";
              name = "root";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "8G";
                    };
                  };
                };
              };
            };

            # LVM physical volume for Proxmox VM storage (local-lvm)
            pve = {
              size = "100%";
              name = "pve";
              content = {
                type = "lvm_pv";
                vg = "pve";
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pve = {
        type = "lvm_vg";
        lvs = {
          data = {
            size = "95%FREE";
            lvm_type = "thin-pool";
          };
        };
      };
    };
  };
}
