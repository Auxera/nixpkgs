import { readdir, readFile, writeFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { exec } from "../lib/exec";

async function upsertPr(args: {
  branch: string;
  title: string;
  body: string;
  labels: string[];
}): Promise<number> {
  const existing = await exec([
    "gh",
    "pr",
    "list",
    "--head",
    args.branch,
    "--json",
    "number",
    "--jq",
    ".[0].number // empty",
  ]);

  const numberText = existing.stdout.trim();
  if (numberText.length > 0) {
    await exec(["gh", "pr", "edit", numberText, "--title", args.title, "--body", args.body]);
    for (const label of args.labels) {
      await exec(["gh", "pr", "edit", numberText, "--add-label", label]);
    }
    return Number(numberText);
  }

  const labelArgs = args.labels.flatMap((label) => ["--label", label]);
  await exec([
    "gh",
    "pr",
    "create",
    "--base",
    "main",
    "--head",
    args.branch,
    "--title",
    args.title,
    "--body",
    args.body,
    ...labelArgs,
  ]);

  const created = await exec([
    "gh",
    "pr",
    "list",
    "--head",
    args.branch,
    "--json",
    "number",
    "--jq",
    ".[0].number // empty",
  ]);

  return Number(created.stdout.trim());
}

async function enableAutoMerge(prNumber: number, enabled: boolean): Promise<void> {
  if (!enabled) {
    return;
  }
  await exec(["gh", "pr", "merge", String(prNumber), "--auto"]);
}

async function collectHashFiles(artifactRoot: string, pkgName: string): Promise<Map<string, string>> {
  const hashes = new Map<string, string>();

  const pkgArtifactDir = join(artifactRoot, `output-hash-${pkgName}`);
  try {
    const entries = await readdir(pkgArtifactDir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const hashFile = join(pkgArtifactDir, entry.name, "pkgs", pkgName, "output-hashes");
      try {
        const systemFiles = await readdir(hashFile, { withFileTypes: true });
        for (const sf of systemFiles) {
          if (sf.isFile() && sf.name.endsWith(".txt")) {
            const system = sf.name.replace(".txt", "");
            const content = await readFile(join(hashFile, sf.name), "utf8");
            hashes.set(system, content.trim());
          }
        }
      } catch {
        // no output-hashes dir in this artifact
      }
    }
  } catch {
    // no artifact dir for this package
  }

  return hashes;
}

export async function finalizePr(args: {
  type: "package" | "flake-input";
  name: string;
  branch: string;
  currentVersion: string;
  newVersion: string;
  artifactRoot: string;
  autoMerge: boolean;
  labels: string[];
}): Promise<number> {
  await exec(["git", "fetch", "origin", args.branch]);
  await exec(["git", "checkout", args.branch]);

  if (args.type === "package") {
    const hashes = await collectHashFiles(args.artifactRoot, args.name);
    for (const [system, hash] of hashes) {
      const hashPath = join("pkgs", args.name, "output-hashes", `${system}.txt`);
      await mkdir(dirname(hashPath), { recursive: true });
      await writeFile(hashPath, `${hash}\n`, "utf8");
    }

    const changed = hashes.size > 0;
    if (changed) {
      await exec(["git", "add", `pkgs/${args.name}/output-hashes`]);
      await exec(["git", "commit", "-m", `${args.name}: add output hashes`]);
      await exec(["git", "push", "origin", args.branch]);
    }
  }

  const title =
    args.type === "package"
      ? `${args.name}: ${args.currentVersion} -> ${args.newVersion}`
      : `flake.lock: update all inputs`;

  const body =
    args.type === "package"
      ? `Automated update for ${args.name} from ${args.currentVersion} to ${args.newVersion}.`
      : `Automated flake input update.`;

  const prNumber = await upsertPr({
    branch: args.branch,
    title,
    body,
    labels: args.labels,
  });

  await enableAutoMerge(prNumber, args.autoMerge);

  return prNumber;
}
