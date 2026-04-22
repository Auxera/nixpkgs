import { join } from "node:path";
import { exec, checkedExec } from "../lib/exec";
import { parseOutputHashFromBuildLog } from "./apply-update";
import { writeGithubOutput } from "../lib/github-output";

export async function computeOutputHash(args: {
  name: string;
  system: string;
  branch: string;
}): Promise<{
  hash: string | null;
  artifactName: string;
}> {
  const fetchResult = await exec(["git", "fetch", "origin", args.branch]);
  if (fetchResult.exitCode !== 0) {
    return { hash: null, artifactName: `output-hash-${args.name}-${args.system}` };
  }
  await checkedExec(["git", "checkout", args.branch]);

  const buildResult = await exec([
    "nix",
    "build",
    "--print-build-logs",
    `.#packages.${args.system}.${args.name}`,
  ]);

  if (buildResult.exitCode === 0) {
    const hashPath = join("pkgs", args.name, "output-hashes", `${args.system}.txt`);
    const { readFile: readFileFs, writeFile, mkdir } = await import("node:fs/promises");
    const { dirname } = await import("node:path");
    await mkdir(dirname(hashPath), { recursive: true });
    try {
      const existing = await readFileFs(hashPath, "utf8");
      if (existing.trim().length > 0) {
        const artifactName = `output-hash-${args.name}-${args.system}`;
        writeGithubOutput("hash", existing.trim());
        writeGithubOutput("artifact_name", artifactName);
        return { hash: existing.trim(), artifactName };
      }
    } catch {
      // file doesn't exist yet
    }
    const artifactName = `output-hash-${args.name}-${args.system}`;
    writeGithubOutput("hash", "");
    writeGithubOutput("artifact_name", artifactName);
    return { hash: null, artifactName };
  }

  const hash = parseOutputHashFromBuildLog(buildResult.stderr);

  if (!hash) {
    const artifactName = `output-hash-${args.name}-${args.system}`;
    writeGithubOutput("hash", "");
    writeGithubOutput("artifact_name", artifactName);
    return { hash: null, artifactName };
  }

  const hashPath = join("pkgs", args.name, "output-hashes", `${args.system}.txt`);
  const { writeFile, mkdir } = await import("node:fs/promises");
  const { dirname } = await import("node:path");
  await mkdir(dirname(hashPath), { recursive: true });
  await writeFile(hashPath, `${hash}\n`, "utf8");

  const artifactName = `output-hash-${args.name}-${args.system}`;
  writeGithubOutput("hash", hash);
  writeGithubOutput("artifact_name", artifactName);

  return { hash, artifactName };
}
