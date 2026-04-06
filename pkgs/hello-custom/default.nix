{
  stdenvNoCC,
  lib,
}:
stdenvNoCC.mkDerivation {
  pname = "hello-custom";
  version = "0.1.0";

  dontUnpack = true;

  installPhase = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/hello-custom" <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    name="''${HELLO_CUSTOM_NAME:-mini-nixpkgs}"
    printf 'Hello from %s\n' "$name"
    EOF
        chmod +x "$out/bin/hello-custom"
  '';

  meta = {
    description = "Tiny starter package for a mini nixpkgs";
    mainProgram = "hello-custom";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
