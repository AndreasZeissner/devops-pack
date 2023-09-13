{ config, lib, pkgs, ... }:

let
  inherit (lib) attrsets types mkIf mkEnableOption mkOption;
  inherit (attrsets) mapAttrsToList;
  cfg = config.services.nexus;
in {
  options.services.nexus = {
    enable = mkEnableOption (lib.mdDoc "nexus");

    name = mkOption {
      default = "nexus-devops-pack";
      type = types.str;
      description = ''
        Prefix to use for the nexus deployment.
      '';
    };

    hostPort = mkOption {
      default = 8081;
      type = types.number;
      description = ''
        Default host port to bind to.
      '';
    };

    extraDockerConfig = mkOption {
      default = "";
      type = types.str;
      description = ''
        Lazy extra config for options passed to the docker run command.
      '';
    };

    initialAdminPassword = mkOption {
      default = "admin123";
      type = types.str;
      description = ''
        Password to be set on the nexus instance.
      '';
    };

    persist = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Used to run a persistent nexus instance which will store it's state on the host.
        This will also run the container in dispatched mode and run a health check when used in `devenv up` to keep the process alive.
      '';
    };
  };

  config = let
    inherit (cfg) name extraDockerConfig initialAdminPassword hostPort persist;
    scripts = import ./scripts.nix {
      inherit name extraDockerConfig hostPort persist initialAdminPassword;
    };
  in mkIf cfg.enable {
    packages = mapAttrsToList pkgs.writeShellScriptBin scripts;

    processes.nexus = {
      exec = scripts.nexus-process;

      process-compose = {
        readiness_probe = {
          exec.command = scripts.nexus-health.cmd;
          initial_delay_seconds = 60;
          period_seconds = 30;
          timeout_seconds = 3;
          success_threshold = 1;
          failure_threshold = 5;
        };
      };
    };
  };
}
