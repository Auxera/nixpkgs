import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { validateUpdateArtifacts, type ArtifactMetadata } from "../artifacts/validate-update-artifacts";
import { upsertPr } from "../pr/upsert-pr";
import { enableAutoMerge } from "../pr/enable-auto-merge";

export function groupByUpdateTarget(
  items: Array<Pick<ArtifactMetadata, "type" | "name" | "system">>,
): Array<{ type: "package" | "flake-input"; name: string; systems: string[] }> {
  const grouped = new Map<string, { type: "package" | "flake-input"; name: string; systems: string[] }>();

  for (const item of items) {
    const key = `${item.type}|${item.name}`;
    if (!grouped.has(key)) {
      grouped.set(key, {
        type: item.type,
        name: item.name,
        systems: [],
      });
    }
    grouped.get(key)!.systems.push(item.system);
  }

  return Array.from(grouped.values()).map((entry) => ({
    ...entry,
    systems: Array.from(new Set(entry.systems)).sort(),
  }));
}

async function listMetadataFiles(root: string): Promise<string[]> {
  const entries = await readdir(root, { withFileTypes: true });
  const files: string[] = [];

  for (const entry of entries) {
    const next = join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listMetadataFiles(next)));
      continue;
    }
    if (entry.isFile() && entry.name === "metadata.json") {
      files.push(next);
    }
  }

  return files;
}

export async function composePrs(args: {
  artifactRoot: string;
  autoMerge: boolean;
  labels: string[];
}): Promise<number> {
  const metadataFiles = await listMetadataFiles(args.artifactRoot);
  const metadata: ArtifactMetadata[] = [];

  for (const file of metadataFiles) {
    const raw = await readFile(file, "utf8");
    metadata.push(JSON.parse(raw) as ArtifactMetadata);
  }

  validateUpdateArtifacts(metadata);

  const grouped = groupByUpdateTarget(metadata.map((item) => ({
    type: item.type,
    name: item.name,
    system: item.system,
  })));

  let processed = 0;
  for (const group of grouped) {
    const branch = group.type === "package" ? `update/${group.name}` : `update-input/${group.name}`;
    const title =
      group.type === "package"
        ? `${group.name}: automated update`
        : `flake.lock: update ${group.name}`;
    const body =
      group.type === "package"
        ? `Automated update for ${group.name}.\n\nSystems: ${group.systems.join(", ")}.`
        : `Automated flake input update for ${group.name}.`;

    const prNumber = await upsertPr({
      branch,
      title,
      body,
      labels: args.labels,
    });
    await enableAutoMerge(prNumber, args.autoMerge);
    processed += 1;
  }

  return processed;
}
