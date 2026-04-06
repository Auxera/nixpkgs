# Cachix Cache

This repository uses [Cachix](https://cachix.org) to provide pre-built binaries.

## For Flakes

Add to your flake inputs:

```nix
nixConfig = {
  substituters = ["https://cache.nixos.org" "https://auxera.cachix.org"];
  trustedPublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrA3kbhn2flpey849RP97Bh4="
    "auxera.cachix.org-1:47t8ocmmQE2OyAEipk98QQsAqG9GFz+5yQ4Ey1AjIHM="
  ];
};
```
