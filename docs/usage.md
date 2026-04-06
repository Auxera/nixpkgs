# Auxera nixpkgs usage

This repository is intended to be consumed as an overlay-backed package set and optional Home Manager module collection.

- Add `github:auxera/nixpkgs` as an input.
- Apply `auxeraPkgs.overlays.default` when importing nixpkgs.
- Consume packages from `pkgs.auxera.<package-name>`.
- Prefer enabling `homeManagerModules` so package assets/config are wired automatically.
- Bun plugin packages in this repo currently use fixed-output hashes (`outputHash`) for reproducible builds.
- The flake default package is a tiny `demo` placeholder; use explicit package names for real packages.

Example 1: enable notifier module (no manual XDG file wiring)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    auxeraPkgs.url = "github:auxera/nixpkgs";
  };

  outputs = { nixpkgs, home-manager, auxeraPkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ auxeraPkgs.overlays.default ];
      };
    in
    {
      homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          auxeraPkgs.homeManagerModules.default
          {
            programs.opencode-notifier-plugin.enable = true;
            programs.opencode-notifier-plugin.settings.timeout = 8;
          }
        ];
      };
    };
}
```

Example 2: enable plannotator module with env overrides

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    auxeraPkgs.url = "github:auxera/nixpkgs";
  };

  outputs = { nixpkgs, home-manager, auxeraPkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ auxeraPkgs.overlays.default ];
      };
    in
    {
      homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          auxeraPkgs.homeManagerModules.default
          {
            programs.plannotator-opencode-plugin.enable = true;
            programs.plannotator-opencode-plugin.env = {
              PLANNOTATOR_MODE = "review";
            };
          }
        ];
      };
    };
}
```
