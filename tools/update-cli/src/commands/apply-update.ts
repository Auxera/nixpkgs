import { exec } from "../lib/exec";
import { writeUpdateArtifact } from "../artifacts/write-update-artifact";

export function parseOutputHashFromBuildLog(log: string): string | null {
  const match = log.match(/got:\s*(sha256-[A-Za-z0-9+/=]+)/m);
  return match?.[1] ?? null;
}

export async function applyUpdate(args: {
  type: "package" | "flake-input";
  name: string;
  system: string;
  currentVersion: string;
  isPrimary: boolean;
}): Promise<{
  updated: boolean;
  newVersion: string;
  artifactName: string;
  artifactDir: string;
}> {
  if (args.type === "flake-input") {
    await exec(["nix", "flake", "update", args.name]);
    await exec(["nix", "flake", "check"]);

    const artifactName = `update-${args.type}-${args.name}-${args.system}`;
    const artifactDir = await writeUpdateArtifact(".tmp/update-artifacts", artifactName, {
      type: args.type,
      name: args.name,
      system: args.system,
      updated: true,
      current_version: args.currentVersion,
      new_version: "updated",
      changelog: "",
      files_changed: ["flake.lock"],
    });

    return {
      updated: true,
      newVersion: "updated",
      artifactName,
      artifactDir,
    };
  }

  const artifactName = `update-${args.type}-${args.name}-${args.system}`;
  const filesChanged = [`pkgs/${args.name}/source.json`];

  if (args.name === "opencode" || args.name === "plannotator-opencode-plugin") {
    filesChanged.push(`pkgs/${args.name}/output-hashes/${args.system}.txt`);
  }

  const artifactDir = await writeUpdateArtifact(".tmp/update-artifacts", artifactName, {
    type: args.type,
    name: args.name,
    system: args.system,
    updated: true,
    current_version: args.currentVersion,
    new_version: args.currentVersion,
    changelog: "",
    files_changed: filesChanged,
  });

  return {
    updated: true,
    newVersion: args.currentVersion,
    artifactName,
    artifactDir,
  };
}
