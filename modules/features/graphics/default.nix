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
  options.cyberfighter.features.graphics = {
    enable = lib.mkEnableOption "Hardware graphics acceleration";

    nvidia = {
      enable = lib.mkEnableOption "Nvidia drivers";

      prime = {
        enable = lib.mkEnableOption "Nvidia Prime configuration";
        intelBusId = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Intel GPU bus ID for Prime";
        };
        nvidiaBusId = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Nvidia GPU bus ID for Prime";
        };
      };

      powerManagement = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Nvidia power management";
      };

      openDriver = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use open source Nvidia kernel module";
      };

      containerToolkit = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose the GPU to Docker containers.

          Two settings are needed, not one: the toolkit generates CDI device
          specs at boot, and the docker daemon has to have the `cdi` feature
          turned on before it will honour them. Enabling only the first leaves
          containers starting fine but seeing no GPU.

          Containers then request the device with the CDI syntax
          (`driver: cdi`, `device_ids: [nvidia.com/gpu=all]`), which replaces
          the deprecated `driver: nvidia` / `count: all` form.
        '';
      };
    };

    amd = {
      enable = lib.mkEnableOption "AMD drivers";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hardware.graphics.enable = true;

        environment.systemPackages = with pkgs; [
          vulkan-tools
          vulkan-loader
          virtualgl
          mesa
          nvtopPackages.nvidia
        ];
      }

      (lib.mkIf cfg.nvidia.enable {
        services.xserver.videoDrivers = [ "nvidia" ];

        environment.sessionVariables = {
          CUDA_PATH = "${pkgs.cudatoolkit}";
          EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
          EXTRA_CCFLAGS = "-I/usr/include";
          LD_LIBRARY_PATH = [
            "/usr/lib/wsl/lib"
            "${pkgs.linuxPackages.nvidia_x11}/lib"
            "${pkgs.ncurses5}/lib"
          ];
          MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
        };

        hardware.nvidia = {
          modesetting.enable = true;
          powerManagement.enable = cfg.nvidia.powerManagement;
          powerManagement.finegrained = false;
          open = cfg.nvidia.openDriver;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
        };
      })

      (lib.mkIf (cfg.nvidia.enable && cfg.nvidia.containerToolkit) {
        hardware.nvidia-container-toolkit.enable = true;
        virtualisation.docker.daemon.settings.features.cdi = true;
      })

      (lib.mkIf (cfg.nvidia.enable && cfg.nvidia.prime.enable) {
        hardware.nvidia.prime = {
          sync.enable = true;
          inherit (cfg.nvidia.prime) intelBusId;
          inherit (cfg.nvidia.prime) nvidiaBusId;
        };
      })

      (lib.mkIf cfg.amd.enable {
        boot.initrd.kernelModules = [ "amdgpu" ];

        services.xserver = {
          enable = true;
          videoDrivers = [ "amdgpu" ];
        };

        hardware.graphics.extraPackages = with pkgs; [
          rocmPackages.clr.icd
        ];

        environment.systemPackages = with pkgs; [
          clinfo
          amdgpu_top
        ];
      })
    ]
  );
}
