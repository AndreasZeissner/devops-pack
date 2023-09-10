{ config, lib, pkgs, ... }:

let
  inherit (lib) attrsets types mkIf mkEnableOption mkOption;
  inherit (attrsets) mapAttrsToList;

  cfg = config.services.kind;
in {
  options.services.kind = {
    enable = mkEnableOption (lib.mdDoc "kind");

    clusterName = mkOption {
      default = "kind-devops-pack";
      type = types.str;
    };

    ingress = mkOption {
      default = false;
      type = types.bool;
    };

    clusterDefinition = mkOption {
      default = ''
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
        - role: control-plane
          kubeadmConfigPatches:
          - |
            kind: InitConfiguration
            nodeRegistration:
              kubeletExtraArgs:
                node-labels: "ingress-ready=true"
          extraPortMappings:
          - containerPort: 80
            hostPort: 80
            protocol: TCP
          - containerPort: 443
            hostPort: 443
            protocol: TCP
      '';
      type = types.str;
    };

    features = mkOption {
      default = {
        flux = {
          enable = false;
          values = "";
        };
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
      definition = cfg.clusterDefinition;
      ingress = cfg.ingress;
      features = cfg.features;
      options = { persist = cfg.persist; };
    };

    argocd = import ./scripts/argocd.nix { inherit cluster; };
    flux = import ./scripts/flux.nix { inherit cluster; };

    scripts = import ./scripts.nix { inherit cluster argocd flux; };

  in mkIf cfg.enable {
    packages = [ pkgs.kubernetes-helm ]
      ++ mapAttrsToList (pkgs.writeShellScriptBin) scripts
      ++ (if cluster.features.argocd.enable then
        [ pkgs.argocd ] ++ mapAttrsToList (pkgs.writeShellScriptBin) argocd
      else
        [ ]) ++ (if cluster.features.flux.enable then
          [ pkgs.fluxcd ] ++ mapAttrsToList (pkgs.writeShellScriptBin) flux
        else
          [ ]);

    processes.kind = {
      exec = ''
        set -e
        ${scripts.kind-clean}
        ${scripts.kind-up}
        ${scripts.kind-features-bootstrap}
        ${scripts.kind-health}
      '';

      process-compose = {
        readiness_probe = {
          exec.command = scripts.kind-health-cmd;
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
