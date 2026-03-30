# Template for a minimal server
{
  lib,
  pkgs,
  hostProfile,
  hostMeta,
  ...
}@inputs:
let
  proxmoxKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP3lFwujAAvXHMk+tj4BkILJTRbAM9guMsg/83SLnaOXg1vLiVnVQvjcyL8UzCekLh6GS6s9YDOhDRymgrlOJrqFBGVDvlsQuMtXaGT0LUkpuv+X18NrSxkW3Dm8JpXr5bQvp/z0MeySNwGIiTvR3ewbU6EbeFe/2xu4wDeq+AvKV76SEDCRpyZwvFVm5YJebaFUXsBT7y1a5cA5VLSHoQKmZDjdCjc+13d175gYwpg0P8+9nlyFjKmmaqBBPz9G16qJk3zEw0un+85NXar96bv0FI+r/wosiSzrV2DpRSqmWzGGVut8VecjubK0cFwh51u+T9g4NyhmSGl4JStE7h root@proxmox"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMKts6SqpPy0yt7QXHo9UizFhu6rYPmqQPgyIApk/S1DNtZtEwQhardEuMLOTqNcjDWOzOMsLc0Shq1htEs/V4+oyiEjLJPuZSr466W3AzY/xag+XxRBIr1QWi2BKBihOMHvtyqZgFLx6G53y8qv753oxxX1x8fn5sWngUTvWUg2rVMrPKrUmFXBE1n8gsgAkkyQXBKHGd8zre9MZ6zqLm9cTRvuNlXSbtvV8fzX3EGbjxkqqax0/RHCWYtcBs4aW1ifwCV8zd2/XSWZiLBF5N1GkckMAcowjMXX0pOztnlWb5h0+9l05f5qF0tE7Da5WhVfFCKgvHglmgokma99t9 root@r610-vm2"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSAocByVGjRoLbUGAwxO2kx8LJ4rbd+FhSOexo7YD5Scs0iqyiQBBn+vGASQGv49WJzM0C0wN4rPpOsiY/3dQ9J0xm/TM9L40cbkf1wjp+WAx2PFUjVjjhY/5dBxGDzvNSwt/Zuo7+pnSRVGY04lxPxDCdAvG68yr8Qk5agpgQrgF5/meKtmSnMFPJDAS9TGU7eFbCSCShmvHAzEBM+jqRMQYSMRRnuLMj/ECvLx6Ww20DCit6blGizGNowNQvwgN/9I8j6kd1luq48YRcIzMg4i4yR1XJgLy3GMFPbzc0VevQwz2skqlwhjKvR74+5m8DpOdkwwvgRF1C5RiinoAH root@proxmox-test"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNITxu8d5c/W7I8TGsopu4i6wN9uH8XUs7X1yxNsx9y9LGks7HmISYXOlZPlGVyjiXNYKJhWEDJ9IOOVtWt62Z7kvv4M34NXAlkQfS+u378M+sMmJipKe6dAFyIM/g/eLiNQgHkJ8mimhNWAZDocHOL97m0F0nSJg1oJ3OAowlxEG3IYlal0aH9fdCKd1tVZG3pdNz2udY/Tpt8Ml2EQin77bD4pinLhf3AuxvnYVOZM6S7Owyk3zmKhC/mjhnEiq/CZDMRF7ustONKrSoDVCvXDfYG49bpB7Qr9y78StcGhSzdi5VVGxCVTV6EvEAfultQenTu/92WbgQn6y2UBR+mtk0+rkTJzvVx7qyHQc5r8kJs0ueLyDsdxgRnEmZO6zlwe8nfcPvCphzJCWH+AmryxYNML0rsgVP5x5ombFjKL7IeofqNNfQQSGOOFrFcPWhmvskBQfrOllxLdAi5oUh1dv6uw6YhBUFPIrzqNjrcy2So+/2yZJML+4x0Vxx8dEGcV4i/IZFC/IjMp4pkwoTGc8GBABP7SopsyDLAY3bJo/AkLWxkpuWxTIG4xctim3LnfnIS6qHygRfqEMyXS6yhDIPVIv80QBvaQOxlVfzNjsFTWGc0WM7GR4n3CyficQHoTAOGdwGmEgmCHoz3kpFrRrI8hUF7A9/sigWU0jInQ== jdguillot@Jonny-Razer"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDWJtS+kpSgwelV8EV3GPWQEcAYVhwfs0O444fRHiSQt9P5ySJ3vS6zt8KYN9Yv2uRiFEi8t9hODJVN2e3xVs4E7EF4ZPNPV9AwWJhuJ2ILiHxyr13qKssx5WxtQ+DkCtSPAib9ptPFWR/58dWA9Ms3GkXI1YT1phQSTIjuNjHMDuaTnb1SQqB3XTl2Wk0K5H1RNvqaAAfMCF5GZ/VeviMOhJZ1/4HJk32r1G10HQWUmyf+Y+Bq9Agmnpx3I/hIPTfjrfiYc3pLgwRBEyWUIcZNlOvFxAzwK+WDnvps5+vcmuvUEt9MKYoxK3yNj8awJw/7IP4ESqOtxQaTPjUYs0DJ root@zb832-pve1"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJpRe/Vuum+djhMDiBhAYNNazPWWGUZwRD4fJ73LYMR9EvjW/5fq0yjK4b3Lz7DC7ADA8uCmSaB4RG6aqt9S2OwsghXQ5ERpZ2MFH0I3yqGwnpPu3wAW3OukhcJRCxouuOTmAiYQOKBO5QLkCa1UzLzEStv8QwtK6dIChGohH178oJL9xUXxJ7qJIH7qpKiE3BpvrYKPFU04IIX2c4V0wqKn+yg3WOGjzc7hgCYhWaXVoXJA5i/CRhbVLezhm+9O9uMYKRzrZqaS5DLz+V2ho8RzDY2frTxV4qmNNkRP7ElyYyNkJJqXxEd4p68yFfpX5Q6BrOy5N3X5oA606iyod7 root@zb432-pve1"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnT8/DmVEqymRlAQzv3/OM97cJ8EmMlCMyyPK5iPz5c5Fp7efu0Cdnk85/b358dTC7WPVoKrRFQZrDXJuWBzzQGDuefmwYf6mZAlsSQGzX3TC8lee1Ub3KZI25hyAanpFUPyuBVCHLXBh3f0LIauveqdnxtciHxIw2xG12fTlhVzyZgbm91Op14QSbZVACNxTB9KjU9mwHKDhU7TfQHGQdPGE+SwEPxAp4IhRC1xKaxVm9f96lcURNZxOwlVjRMJlhtFF9PuVbpQSnzEKbxUpDcw6Ie2GfCgpumi8B3XZ6eJ+WaTyfH6ckvVN8xwSTd499B2vZ82fiGWA53lr5JtfJ root@zb832-pve2"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCNGGSlC2OVN/5gbLkFt0ZIMAMzghamVGV3XWMrv9gQPmwnX6+7DaVa1uVPbLdbDD34HoNFtMOzOXHgp4ywuYI7RBKw6e9pzcFNyun3zUMPBG1/eRU0C1nod2b0W4quyxW+uwXv2kJ8pY02qQq6tJMBkhR++hi/okFq/8jYcSyNO2OStbBA93ssueFAGZfqjBnPjgBAo48sCgV19Tae3zvVc2OLRCi2qsnY7hIHcvvKFaLcORrHuBdk8wZZSt4erzSs2PrwyZGCuHYbHhH4qLQ9V1rIaHB+qQza46+qrSPNiKPUb8jc7RTcM0gmDpG881lVOLgb4LJa7VCWnRaBos25tV7kww1SXx4DrldvF+4j77nDbAxa9FL73TlANy1hETdMqqL7HIbnIRY7fwpueEuRYr1Y2DmMH8EA2YDfKptEBEQUMCiG64SkTuHipiPZSKZ0psvWvevxsORATph27zY/U30ae9mkO5NlBTtfLZ5jF0F/36AdlstuDjQQLqiJ85EDefS/emDwOG64OdbIlPheg9cAp52PkY8SKUnrR8Eusgw4/PEDK+EGkRRR0Uo0IKEPO5Ex3vKwYxte7AYvM9ExHNmUlKc2JlNoCiQtwxyhypkbcxFBn49S/ddCXzhhXMsjjOtNE5UEtgfqtNjYoGjWR+0OuCWPQ6TfG0vHUFquuQ== root@thkpd-pve1"
  ];
in
{
  imports = [
    ../../modules
    inputs.inputs.nix-index-database.nixosModules.nix-index
    ./disk-config.nix
    ./hardware-configuration.nix
    # ./containers
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.11";

      bootloader = {
        systemd-boot = true;
        efiCanTouchVariables = true;
      };

      extraGroups = [ "docker" ];
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    features = {

      proxmox = {
        enable = true;
        ipAddress = "192.168.101.39";
      };

      ssh = {
        enable = true;
        passwordAuth = false; # Key-only authentication
        permitRootLogin = "yes";
      };

      docker = {
        enable = true;
        networks = [ "web" ];
      };
      tailscale.enable = true;

      sops = {
        enable = true;
        defaultSopsFile = ../../secrets/secrets.yaml;
        deployUserAgeKey = true;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "L+ /bin/true - - - - ${pkgs.coreutils}/bin/true"
  ];

  services.proxmox-ve.bridges = [
    "vmbr0"
  ];
  services.resolved.enable = false;

  networking.useNetworkd = true;

  systemd = {
    network = {

      networks."10-lan" = {
        matchConfig.Name = [ "enp0s20f0u1" ];
        networkConfig = {
          Bridge = "vmbr0";
        };
      };

      netdevs."vmbr0" = {
        netdevConfig = {
          Name = "vmbr0";
          Kind = "bridge";
        };
      };

      networks."10-lan-bridge" = {
        matchConfig.Name = "vmbr0";
        networkConfig = {
          DHCP = "no";
          Address = [ "192.168.101.39/24" ];
          Gateway = "192.168.101.1";
          DNS = [
            "192.168.101.1"
            "1.1.1.1"
          ];
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  users.users.root.openssh.authorizedKeys.keys = proxmoxKeys;

  services.openssh.settings = {
    AcceptEnv = lib.mkForce [
      "LANG"
      "LC_*"
    ];
  };

}
