{ config, lib, pkgs, ... }:

let
  inherit (lib) types mkIf mkEnableOption mkOption;

  cfg = config.services.kind;
in {
  options.services.kind = {
    enable = mkEnableOption (lib.mdDoc "kind");

    clusterName = mkOption {
      default = "devops-pack";
      type = types.str;
    };

    features = mkOption {
      default = {
        argocd = {
          enable = false;
          values = "";
        };
      };
      description = ''
        Kubernetes features to be deployed on cluster bootstrap.
      '';
      type = types.attrs;
    };
  };

  config = let
    cluster = {
      name = cfg.clusterName;
      features = cfg.features;
      options = { persist = cfg.persist; };
    };
    scripts = import ./scripts.nix { inherit cluster; };
  in mkIf cfg.enable {
    packages = [ pkgs.kubernetes-helm ]
      ++ (if cluster.features.argocd.enable then [ pkgs.argocd ] else [ ]) ++ [
        (pkgs.writeShellScriptBin "features-bootrap" scripts.features.bootstrap)
        (pkgs.writeShellScriptBin "kind-up" scripts.kind-up)
        (pkgs.writeShellScriptBin "kind-up" scripts.kind-health)
      ];
    processes.kind = {
      exec = ''
        ${scripts.kind-clean}
        ${scripts.kind-up}
        ${scripts.features.bootstrap}
        ${scripts.kind-health}
      '';

      process-compose = {
        readiness_probe = {
          exec.command = "kubectl get cs";
          initial_delay_seconds = 60;
          period_seconds = 10;
          timeout_seconds = 3;
          success_threshold = 1;
          failure_threshold = 5;
        };
      };
    };
  };
}
