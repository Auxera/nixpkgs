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
      overlays.default = final: prev: let
        bun2nixOverlay = bun2nix.overlays.default final prev;
      in
        bun2nixOverlay
        // {
          auxera = import ./pkgs {
            pkgs = final;
            bun2nix = bun2nixOverlay.bun2nix;
          };
        };

      homeManagerModules.default = import ./modules/home-manager;
      homeManagerModules.opencode-notifier-plugin = import ./modules/home-manager/opencode-notifier-plugin;
      homeManagerModules.openspec = import ./modules/home-manager/openspec;
      homeManagerModules.plannotator-opencode-plugin = import ./modules/home-manager/plannotator-opencode-plugin;
      homeManagerModules.superpowers-opencode-plugin = import ./modules/home-manager/superpowers-opencode-plugin;
    }
    // flake-utils.lib.eachSystem systems (
      system: let
        alejandra = pkgs.alejandra;

        # nixpkgs removed pnpm_9 (EOL 2026-04-30). openspec still depends on
        # it; that migration is happening separately, so keep 9.15.9 here.
        pnpm9Overlay = final: prev: {
          pnpm_9 = final.callPackage (nixpkgs + "/pkgs/development/tools/pnpm/generic.nix") {
            version = "9.15.9";
            hash = "sha256-z4anrXZEBjldQoam0J1zBxFyCsxtk+nc6ax6xNxKKKc=";
            nodejs = null;
          };
        };

        pkgs = import nixpkgs {
          inherit system alejandra;
          overlays = [self.overlays.default bun2nix.overlays.default pnpm9Overlay];
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
