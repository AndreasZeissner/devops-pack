{
  description = ''
    devops-pack: devenv extensions used to hack around with common devops tooling
  '';

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { nixpkgs, flake-utils, devenv, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        packages = [ ];

        nixosModules = {
          kind = import ./src/modules/kind;
          nexus = import ./src/modules/nexus;
        };

        devShell = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [{
            inherit packages;
            imports = [ nixosModules.kind nixosModules.nexus ];
            services = {
              nexus = { enable = true; };
              kind = {
                enable = true;
                features = {
                  flux = {
                    enable = true;
                    values = "";
                  };
                  argocd = {
                    enable = false;
                    values = "";
                  };
                };
              };
            };
          }];
        };
      in {
        inherit nixosModules devShell;
        apps = {
          devops-pack-app-ok = {
            type = "app";
            program = toString (pkgs.writeShellScript "devops-pack-app-ok" ''
              echo "devops-pack-ok ${system} $@"
            '');
          };
        };
        packages = rec {
          devops-pack-package-ok =
            pkgs.writeScriptBin "devops-pack-package-ok" ''
              echo "devops-pack-ok ${system} $@"
            '';
          default = devops-pack-package-ok;
        };
      });
}

