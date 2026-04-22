import { PLATFORMS, RUNNER_BY_SYSTEM } from "../config/platforms";

export type PackageMeta = {
  name: string;
  version: string;
  sourceInfo: { owner: string; repo: string };
  platforms: string[];
  needsOutputHash: boolean;
  hasBunNix: boolean;
};

export type ApplyEntry = {
  type: "package" | "flake-input";
  name: string;
  current_version: string;
  latest_version: string;
  owner: string;
  repo: string;
  branch: string;
  systems_needing_output_hash: string[];
  has_bun_nix: boolean;
};

export type HashEntry = {
  name: string;
  system: string;
  runs_on: string;
  branch: string;
};

export async function discoverUpdates(args: {
  selectedPackages: string[];
  hashRefresh: boolean;
  packages: PackageMeta[];
  getLatestVersion: (name: string) => Promise<string | null>;
}): Promise<{
  hasUpdates: boolean;
  apply_matrix: { include: ApplyEntry[] };
  hash_matrix: { include: HashEntry[] };
}> {
  const applyInclude: ApplyEntry[] = [];
  const hashInclude: HashEntry[] = [];

  const packageFilter = new Set(args.selectedPackages);

  for (const pkg of args.packages) {
    if (packageFilter.size > 0 && !packageFilter.has(pkg.name)) {
      console.log(`[discover] skipping ${pkg.name}: not in selected packages`);
      continue;
    }

    if (!args.hashRefresh) {
      const latest = await args.getLatestVersion(pkg.name);
      if (!latest) {
        console.log(`[discover] skipping ${pkg.name}: could not determine latest version (owner=${pkg.sourceInfo.owner}, repo=${pkg.sourceInfo.repo})`);
        continue;
      }

      if (pkg.version === latest) {
        console.log(`[discover] skipping ${pkg.name}: already up to date (${pkg.version})`);
        continue;
      }

      console.log(`[discover] update available: ${pkg.name} ${pkg.version} -> ${latest}`);

      const systemsNeedingHash = pkg.needsOutputHash
        ? PLATFORMS.filter((p) => pkg.platforms.includes(p.system)).map((p) => p.system)
        : [];

      applyInclude.push({
        type: "package",
        name: pkg.name,
        current_version: pkg.version,
        latest_version: latest,
        owner: pkg.sourceInfo.owner,
        repo: pkg.sourceInfo.repo,
        branch: `update/${pkg.name}`,
        systems_needing_output_hash: systemsNeedingHash,
        has_bun_nix: pkg.hasBunNix,
      });

      for (const system of systemsNeedingHash) {
        const platform = PLATFORMS.find((p) => p.system === system);
        hashInclude.push({
          name: pkg.name,
          system,
          runs_on: platform ? RUNNER_BY_SYSTEM[platform.system] : "ubuntu-latest",
          branch: `update/${pkg.name}`,
        });
      }
    } else {
      console.log(`[discover] hash-refresh: ${pkg.name} at ${pkg.version}`);
      const systemsNeedingHash = pkg.needsOutputHash
        ? PLATFORMS.filter((p) => pkg.platforms.includes(p.system)).map((p) => p.system)
        : [];

      applyInclude.push({
        type: "package",
        name: pkg.name,
        current_version: pkg.version,
        latest_version: pkg.version,
        owner: pkg.sourceInfo.owner,
        repo: pkg.sourceInfo.repo,
        branch: `update/${pkg.name}`,
        systems_needing_output_hash: systemsNeedingHash,
        has_bun_nix: pkg.hasBunNix,
      });

      for (const system of systemsNeedingHash) {
        const platform = PLATFORMS.find((p) => p.system === system);
        hashInclude.push({
          name: pkg.name,
          system,
          runs_on: platform ? RUNNER_BY_SYSTEM[platform.system] : "ubuntu-latest",
          branch: `update/${pkg.name}`,
        });
      }
    }
  }

  if (!args.hashRefresh) {
    applyInclude.push({
      type: "flake-input",
      name: "flake-inputs",
      current_version: "unknown",
      latest_version: "unknown",
      owner: "",
      repo: "",
      branch: "update/flake-inputs",
      systems_needing_output_hash: [],
      has_bun_nix: false,
    });
  }

  console.log(`[discover] summary: ${applyInclude.length} update(s) to apply, ${hashInclude.length} output hash(es) to compute`);

  return {
    hasUpdates: applyInclude.length > 0,
    apply_matrix: { include: applyInclude },
    hash_matrix: { include: hashInclude },
  };
}
