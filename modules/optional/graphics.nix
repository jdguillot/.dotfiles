{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.graphics;
in
{

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Enable OpenGL
      hardware.graphics = {
        enable = true;
      };
      environment.systemPackages = with pkgs; [
        vulkan-tools
        vulkan-loader
        virtualgl
      ];
    })

    (lib.mkIf (cfg.enable && cfg.nvidia) {
      # Load nvidia driver for Xorg and Wayland
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {

        # Modesetting is required.
        modesetting.enable = true;

        # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
        # Enable this if you have graphical corruption issues or application crashes after waking
        # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
        # of just the bare essentials.
        powerManagement.enable = false;

        # Fine-grained power management. Turns off GPU when not in use.
        # Experimental and only works on modern Nvidia GPUs (Turing or newer).
        powerManagement.finegrained = false;

        # Use the NVidia open source kernel module (not to be confused with the
        # independent third-party "nouveau" open source driver).
        # Support is limited to the Turing and later architectures. Full list of
        # supported GPUs is at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
        # Only available from driver 515.43.04+
        open = true;

        # Enable the Nvidia settings menu,
        # accessible via `nvidia-settings`.
        nvidiaSettings = true;

        # Optionally, you may need to select the appropriate driver version for your specific GPU.
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    })
    (lib.mkIf (cfg.enable && cfg.amd) {
      boot.initrd.kernelModules = [ "amdgpu" ];

      services.xserver.enable = true;
      services.xserver.videoDrivers = [ "amdgpu" ];

      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];

      environment.systemPackages = with pkgs; [
        clinfo
        amdgpu_top
      ];
    })
  ];
}
