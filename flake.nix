{
  description = "Auxera custom nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "flake-utils/systems";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    bun2nix,
    flake-utils,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  in
    {
      overlays.default = final: prev: {
        auxera = import ./pkgs {
          pkgs = final;
        };
      };

      homeManagerModules.default = import ./modules/home-manager;
      homeManagerModules.opencode-notifier-plugin = import ./modules/home-manager/opencode-notifier-plugin;
      homeManagerModules.plannotator-opencode-plugin = import ./modules/home-manager/plannotator-opencode-plugin;
      homeManagerModules.superpowers-opencode-plugin = import ./modules/home-manager/superpowers-opencode-plugin;
    }
    // flake-utils.lib.eachSystem systems (
      system: let
        alejandra = pkgs.alejandra;

        pkgs = import nixpkgs {
          inherit system alejandra;
          overlays = [self.overlays.default bun2nix.overlays.default];
        };

        auxera-pkgs = pkgs.auxera;
        supported =
          pkgs.lib.filterAttrs (
            name: pkg:
              pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkg
          )
          auxera-pkgs;
      in {
        packages =
          supported
          // {
            default = auxera-pkgs.opencode;
          };

        checks.formatting = pkgs.runCommand "alejandra-check" {} ''
          cd ${self}
          ${pkgs.alejandra}/bin/alejandra --check .
          touch $out
        '';

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            git
            nix-update
            bun2nix.packages.${system}.bun2nix
          ];
        };
      }
    );
}
