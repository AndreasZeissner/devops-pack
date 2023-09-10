_:

let env = { PROJECT_ROOT = builtins.getEnv "PWD"; };
in {
  inherit env;

  imports = [ ./src/modules/kind/default.nix ./src/modules/nexus/default.nix ];

  services = {
    nexus = { enable = true; };
    kind = {
      enable = true;
      features = {
        flux = {
          enable = false;
          values = "";
        };
        argocd = {
          enable = false;
          values = ''
            crds:
              install: true
              keep: true
              annotations: {}
              additionalLabels: {}
            configs:
              cm:
                create: true
            server:
              insecure: true
              ingress:
                enabled: true
                ingressClassName: nginx
                annotations:
                  nginx.ingress.kubernetes.io/backend-protocol: HTTPS
                  nginx.ingress.kubernetes.io/force-ssl-redirect: false
            redis-ha:
              enabled: false
          '';
        };
      };
    };
  };

  languages.nix.enable = true;

  pre-commit.hooks = {
    shellcheck.enable = true;
    deadnix.enable = true;
    nixfmt.enable = true;
  };
}
