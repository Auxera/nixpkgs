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
      "aarch64-linux"
      "aarch64-darwin"
    ];
  in
    {
      overlays.default = final: prev: let
        bunOverlay = bun2nix.overlays.default final prev;
      in
        (import ./overlay.nix final prev)
        // bunOverlay;

      homeManagerModules.default = import ./modules/home-manager;
      homeManagerModules.opencode-notifier-plugin = import ./modules/home-manager/opencode-notifier-plugin;
      homeManagerModules.plannotator-opencode-plugin = import ./modules/home-manager/plannotator-opencode-plugin;
      homeManagerModules.superpowers-opencode-plugin = import ./modules/home-manager/superpowers-opencode-plugin;
    }
    // flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
        auxera-pkgs = pkgs.auxera;
      in {
        packages =
          auxera-pkgs
          // {
            opencode = auxera-pkgs.opencode;
            default = auxera-pkgs.demo;
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
          ];
        };
      }
    );
}
