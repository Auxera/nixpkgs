import { PLATFORMS, RUNNER_BY_SYSTEM } from "../config/platforms";

type UpdateTarget = {
  type: "package" | "flake-input";
  name: string;
  system: string;
  runs_on: string;
  current_version: string;
  is_primary?: boolean;
};

export async function discoverUpdates(args: {
  selectedPackages: string[];
  selectedInputs: string[];
  packageNames: string[];
  getCurrentVersion: (name: string) => Promise<string>;
  getLatestVersion: (name: string) => Promise<string>;
  listFlakeInputs: () => Promise<string[]>;
}): Promise<{ hasUpdates: boolean; matrix: { include: UpdateTarget[] } }> {
  const include: UpdateTarget[] = [];

  const packageFilter = new Set(args.selectedPackages);
  for (const name of args.packageNames) {
    if (packageFilter.size > 0 && !packageFilter.has(name)) {
      continue;
    }

    const current = await args.getCurrentVersion(name);
    const latest = await args.getLatestVersion(name);
    if (current === latest) {
      continue;
    }

    for (const platform of PLATFORMS) {
      include.push({
        type: "package",
        name,
        system: platform.system,
        runs_on: RUNNER_BY_SYSTEM[platform.system],
        current_version: current,
        is_primary: platform.system === "x86_64-linux",
      });
    }
  }

  const inputs = await args.listFlakeInputs();
  const inputFilter = new Set(args.selectedInputs);
  for (const input of inputs) {
    if (inputFilter.size > 0 && !inputFilter.has(input)) {
      continue;
    }
    include.push({
      type: "flake-input",
      name: input,
      system: "x86_64-linux",
      runs_on: RUNNER_BY_SYSTEM["x86_64-linux"],
      current_version: "unknown",
    });
  }

  return { hasUpdates: include.length > 0, matrix: { include } };
}
