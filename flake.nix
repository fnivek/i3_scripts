{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
      p2ns = forAllSystems (system: poetry2nix.lib.mkPoetry2Nix { pkgs = pkgs.${system}; });
      pypkgs-build-requirements = {
        python-xlib = [ "setuptools-scm" ];
      };
      p2n-overrides = forAllSystems (system:
        p2ns.${system}.defaultPoetryOverrides.extend (final: prev:
          builtins.mapAttrs (package: build-requirements: 
            (builtins.getAttr package prev).overridePythonAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++
                (builtins.map
                  (pkg: if builtins.isString pkg
                    then builtins.getAttr pkg prev
                    else pkg) build-requirements);
            })
          ) pypkgs-build-requirements
        )
      );
    in
    {
      packages = forAllSystems (system: let
        inherit (p2ns.${system}) mkPoetryApplication;
        p2n-override = p2n-overrides.${system};
      in {
        default = mkPoetryApplication {
          projectDir = self;
          overrides = p2n-override;
        };
      });

      devShells = forAllSystems (system: let
        inherit (p2ns.${system}) mkPoetryEnv;
        p2n-override = p2n-overrides.${system};
      in {
        default = pkgs.${system}.mkShellNoCC {
          packages = with pkgs.${system}; [
            (mkPoetryEnv {
              projectDir = self;
              overrides = p2n-override;
            })
            poetry
          ];
          
        };
      });
    };
}
