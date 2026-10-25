{
  description = "Auxera custom nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Tracks nixos-unstable independently of the main pin: t3code's desktop
    # needs electron_44, which the main pin does not provide yet. Drop this
    # input and take electron_44 from nixpkgs once the pin catches up.
    nixpkgs-electron.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    nixpkgs-electron,
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

        # electron_44 and a newer pnpm_11 for the t3code packages; see the
        # nixpkgs-electron input comment above. The main pin's pnpm (11.8.0)
        # predates upstream's 11.10.0 pin and aborts (SIGABRT) while
        # fetching the stable tree on macOS CI runners; 11.27 does not.
        electronOverlay = final: prev: {
          pnpm_11 = nixpkgs-electron.legacyPackages.${system}.pnpm_11;
          electron_44 = nixpkgs-electron.legacyPackages.${system}.electron_44;
        };

        pkgs = import nixpkgs {
          inherit system alejandra;
          overlays = [self.overlays.default bun2nix.overlays.default electronOverlay];
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
