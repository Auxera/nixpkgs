import { PLATFORMS, RUNNER_BY_SYSTEM } from "../config/platforms";

export type PackageMeta = {
  name: string;
  version: string;
  sourceInfo: { owner: string; repo: string };
  platforms: string[];
  needsOutputHash: boolean;
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
      continue;
    }

    const latest = await args.getLatestVersion(pkg.name);
    if (!latest) {
      continue;
    }

    if (!args.hashRefresh && pkg.version === latest) {
      continue;
    }

    const systemsNeedingHash = pkg.needsOutputHash
      ? PLATFORMS.filter((p) => pkg.platforms.includes(p.system)).map((p) => p.system)
      : [];

    applyInclude.push({
      type: "package",
      name: pkg.name,
      current_version: pkg.version,
      latest_version: args.hashRefresh ? pkg.version : latest,
      owner: pkg.sourceInfo.owner,
      repo: pkg.sourceInfo.repo,
      branch: `update/${pkg.name}`,
      systems_needing_output_hash: systemsNeedingHash,
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

  applyInclude.push({
    type: "flake-input",
    name: "flake-inputs",
    current_version: "unknown",
    latest_version: "unknown",
    owner: "",
    repo: "",
    branch: "update/flake-inputs",
    systems_needing_output_hash: [],
  });

  return {
    hasUpdates: applyInclude.length > 0,
    apply_matrix: { include: applyInclude },
    hash_matrix: { include: hashInclude },
  };
}
