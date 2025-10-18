{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-diskseq/1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/rootfs" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd:3" ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                    ];
                  };
                  "/var" = {
                    mountpoint = "/var";
                    mountOptions = [ "compress=zstd:3" ];
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    mountOptions = [
                      "noatime"
                      "nodatacow"
                    ];
                    swap = {
                      swapfile = {
                        size = "4G";
                      };
                    };
                  };
                };
                mountpoint = "/partition-root";
              };
            };
          };
        };
      };
    };
  };
}
