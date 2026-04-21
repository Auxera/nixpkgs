import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

type LegacyHashes = {
  version: string;
  hash: Record<string, string>;
  outputHash?: Record<string, string>;
};

const packages = [
  "opencode",
  "plannotator-opencode-plugin",
  "opencode-notifier-plugin",
  "superpowers-opencode-plugin",
] as const;

async function writeText(filePath: string, content: string): Promise<void> {
  await mkdir(dirname(filePath), { recursive: true });
  await writeFile(filePath, content, "utf8");
}

export async function migrateHashes(repoRoot: string): Promise<void> {
  for (const pkg of packages) {
    const hashesPath = join(repoRoot, "pkgs", pkg, "hashes.json");
    const sourcePath = join(repoRoot, "pkgs", pkg, "source.json");
    const raw = await readFile(hashesPath, "utf8");
    const parsed = JSON.parse(raw) as LegacyHashes;

    const sourceData = {
      version: parsed.version,
      hash: parsed.hash,
    };

    await writeText(sourcePath, `${JSON.stringify(sourceData, null, 2)}\n`);

    if (parsed.outputHash) {
      for (const [system, hash] of Object.entries(parsed.outputHash)) {
        const outputHashPath = join(repoRoot, "pkgs", pkg, "output-hashes", `${system}.txt`);
        await writeText(outputHashPath, `${hash}\n`);
      }
    }

    await rm(hashesPath);
  }
}
