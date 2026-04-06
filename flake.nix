{
  description = "Auxera custom nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    opencode,
    ...
  }: let
    systems = [
      "x86_64-linux"
    ];
  in
    {
      overlays.default = final: prev:
        (import ./overlay.nix final prev)
        // {
          opencode = opencode.packages.${final.stdenv.hostPlatform.system}.default;
        };

      homeManagerModules.default = import ./modules/home-manager;
      homeManagerModules.opencode-notifier-plugin = import ./modules/home-manager/opencode-notifier-plugin;
      homeManagerModules.plannotator-opencode-plugin = import ./modules/home-manager/plannotator-opencode-plugin;
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
            opencode = pkgs.opencode;
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
