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
    };

    hostPort = mkOption {
      default = 8081;
      type = types.number;
    };

    initialAdminPassword = mkOption {
      default = "admin123";
      type = types.str;
    };
  };

  config = let
    scripts = import ./scripts.nix {
      hostPort = cfg.hostPort;
      initialAdminPassword = cfg.initialAdminPassword;
      name = cfg.name;
    };
  in mkIf cfg.enable {
    packages = mapAttrsToList (pkgs.writeShellScriptBin) scripts;

    processes.nexus = {
      exec = ''
        set -e
        ${scripts.nexus-clean}
        ${scripts.nexus-docker-pull}
        ${scripts.nexus-up}
        ${scripts.nexus-bootstrap}
        ${scripts.nexus-health}
      '';

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
