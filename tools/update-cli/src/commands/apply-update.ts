import { readFile, writeFile, mkdir, unlink } from "node:fs/promises";
import { join, dirname } from "node:path";
import { exec, checkedExec } from "../lib/exec";

export function parseOutputHashFromBuildLog(log: string): string | null {
  const match = log.match(/got:\s*(sha256-[A-Za-z0-9+/=]+)/m);
  return match?.[1] ?? null;
}

async function prefetchSourceHash(
  owner: string,
  repo: string,
  version: string,
): Promise<string> {
  const url = `https://github.com/${owner}/${repo}/archive/refs/tags/v${version}.tar.gz`;
  const result = await exec([
    "nix-prefetch-url",
    "--type",
    "sha256",
    "--unpack",
    url,
  ]);
  if (result.exitCode !== 0) {
    throw new Error(`nix-prefetch-url failed for ${owner}/${repo} v${version}: ${result.stderr}`);
  }
  return result.stdout.trim();
}

async function updateSourceJson(
  name: string,
  newVersion: string,
  owner: string,
  repo: string,
): Promise<void> {
  const sourcePath = join("pkgs", name, "source.json");
  const raw = await readFile(sourcePath, "utf8");
  const sourceJson = JSON.parse(raw) as Record<string, unknown>;

  sourceJson.version = newVersion;

  const sourceHash = await prefetchSourceHash(owner, repo, newVersion);

  if (typeof sourceJson.hash === "string") {
    sourceJson.hash = sourceHash;
  } else if (typeof sourceJson.hash === "object" && sourceJson.hash !== null) {
    const updated: Record<string, string> = {};
    for (const key of Object.keys(sourceJson.hash as Record<string, string>)) {
      updated[key] = sourceHash;
    }
    sourceJson.hash = updated;
  }

  await writeFile(sourcePath, `${JSON.stringify(sourceJson, null, 2)}\n`, "utf8");
}

async function clearOutputHashes(name: string, systems: string[]): Promise<void> {
  for (const system of systems) {
    const hashPath = join("pkgs", name, "output-hashes", `${system}.txt`);
    await mkdir(dirname(hashPath), { recursive: true });
    await writeFile(hashPath, "\n", "utf8");
  }
}

async function regenerateBunNix(
  name: string,
  owner: string,
  repo: string,
  version: string,
): Promise<void> {
  const bunLockUrl = `https://raw.githubusercontent.com/${owner}/${repo}/v${version}/bun.lock`;
  const tmpLockPath = join("pkgs", name, ".tmp-bun.lock");

  const resp = await fetch(bunLockUrl);
  if (!resp.ok) {
    throw new Error(`failed to fetch bun.lock for ${owner}/${repo} v${version}: ${resp.status}`);
  }
  const bunLock = await resp.text();
  await writeFile(tmpLockPath, bunLock, "utf8");

  try {
    await checkedExec([
      "nix",
      "run",
      ".#bun2nix",
      "--",
      "-l",
      tmpLockPath,
      "-o",
      join("pkgs", name, "bun.nix"),
    ]);
    await checkedExec([
      "nix",
      "run",
      "nixpkgs#alejandra",
      "--",
      join("pkgs", name, "bun.nix"),
    ]);
  } finally {
    await unlink(tmpLockPath).catch(() => {});
  }
}

export async function applyUpdate(args: {
  type: "package" | "flake-input";
  name: string;
  currentVersion: string;
  latestVersion: string;
  hashRefresh: boolean;
  owner: string;
  repo: string;
  systemsNeedingOutputHash: string[];
  hasBunNix: boolean;
}): Promise<{
  updated: boolean;
  newVersion: string;
  branch: string;
}> {
  if (args.type === "flake-input") {
    await exec(["nix", "flake", "update"]);

    const diffResult = await exec(["git", "diff", "--quiet", "flake.lock"]);
    if (diffResult.exitCode === 0) {
      return { updated: false, newVersion: "unknown", branch: "" };
    }

    const branch = "update/flake-inputs";
    await checkedExec(["git", "checkout", "-b", branch]);
    await checkedExec(["git", "add", "flake.lock"]);
    await checkedExec(["git", "commit", "-m", "flake.lock: update all inputs"]);
    await checkedExec(["git", "push", "--force", "origin", branch]);

    return { updated: true, newVersion: "updated", branch };
  }

  const newVersion = args.hashRefresh ? args.currentVersion : args.latestVersion;
  const commitMessage = args.hashRefresh
    ? `${args.name}: hash refresh at ${args.currentVersion}`
    : `${args.name}: ${args.currentVersion} -> ${newVersion}`;

  await updateSourceJson(args.name, newVersion, args.owner, args.repo);
  if (args.hasBunNix) {
    await regenerateBunNix(args.name, args.owner, args.repo, newVersion);
  }
  await clearOutputHashes(args.name, args.systemsNeedingOutputHash);

  const diffResult = await exec(["git", "diff", "--quiet", "--", `pkgs/${args.name}`]);
  if (diffResult.exitCode === 0) {
    return { updated: false, newVersion, branch: "" };
  }

  const branch = `update/${args.name}`;
  await checkedExec(["git", "checkout", "-b", branch]);
  await checkedExec(["git", "add", `pkgs/${args.name}`]);
  await checkedExec(["git", "commit", "-m", commitMessage]);
  await checkedExec(["git", "push", "--force", "origin", branch]);

  return { updated: true, newVersion, branch };
}
