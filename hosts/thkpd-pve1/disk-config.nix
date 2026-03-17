{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        #TODO: Change the device name to whatever is found via lsblk
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
              size = "100%";
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
                      swapfile.size = "4G";
                    };
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
