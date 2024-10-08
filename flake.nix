{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
      p2ns = forAllSystems (system: poetry2nix.lib.mkPoetry2Nix { pkgs = pkgs.${system}; });
      pypkgs-build-requirements = {
        python-xlib = [ "setuptools-scm" ];
        argparse = [ "setuptools" ];
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
        # Simple script to ensure that only one history server is ever running.
        focus_history_server_launch = pkgs.${system}.writeShellApplication {
          name = "focus_history_server_launch";
          runtimeInputs = [ self.packages.${system}.default ];
          text = ''
            # Kill any existing process.
            pid="$(pgrep -f focus_history_server-wrapped || true)"
            if [ -n "$pid" ]; then kill -15 "$pid"; fi
            # Start the server.
            focus_history_server
          '';
        };
        # Toggle touchpad
        toggleTouchpad = pkgs.${system}.writeShellApplication {
          name = "toggle-touchpad";
          runtimeInputs = [];
          text = "${builtins.readFile ./toggle-touchpad}";
        };
        # Toggle touchpad
        toggleDisplays = pkgs.${system}.writeShellApplication {
          name = "toggle-displays";
          runtimeInputs = [];
          text = "${builtins.readFile ./toggle-displays}";
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
