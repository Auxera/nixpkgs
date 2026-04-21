import { PLATFORMS, RUNNER_BY_SYSTEM, type System } from "../config/platforms";

type Target = {
  package: string;
  system: System;
  runs_on: string;
};

const SHARED_FILES = new Set(["flake.nix", "overlay.nix", "pkgs/default.nix"]);
const SHARED_PREFIXES = [".github/workflows/", "tools/update-cli/", "lib/"];

function isShared(file: string): boolean {
  return SHARED_FILES.has(file) || SHARED_PREFIXES.some((prefix) => file.startsWith(prefix));
}

function pkgFromPath(file: string): string | null {
  const parts = file.split("/");
  if (parts[0] !== "pkgs" || parts.length < 2) {
    return null;
  }
  return parts[1] ?? null;
}

export function discoverBuildTargets(args: { changedFiles: string[]; packageNames: string[] }): {
  hasChanges: boolean;
  matrix: { include: Target[] };
} {
  const selected = new Set<string>();

  if (args.changedFiles.some(isShared)) {
    for (const name of args.packageNames) {
      selected.add(name);
    }
  } else {
    for (const file of args.changedFiles) {
      const pkg = pkgFromPath(file);
      if (pkg && args.packageNames.includes(pkg)) {
        selected.add(pkg);
      }
    }
  }

  const include: Target[] = [];
  for (const pkg of Array.from(selected).sort()) {
    for (const platform of PLATFORMS) {
      include.push({
        package: pkg,
        system: platform.system,
        runs_on: RUNNER_BY_SYSTEM[platform.system],
      });
    }
  }

  return { hasChanges: include.length > 0, matrix: { include } };
}
