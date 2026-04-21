import { cp, mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export type UpdateArtifact = {
  type: "package" | "flake-input";
  name: string;
  system: string;
  updated: boolean;
  current_version: string;
  new_version: string;
  changelog: string;
  files_changed: string[];
};

export async function writeUpdateArtifact(root: string, artifactName: string, data: UpdateArtifact): Promise<string> {
  const artifactDir = join(root, artifactName);
  const filesDir = join(artifactDir, "files");
  await mkdir(filesDir, { recursive: true });

  await writeFile(join(artifactDir, "metadata.json"), `${JSON.stringify(data, null, 2)}\n`, "utf8");

  for (const rel of data.files_changed) {
    const destination = join(filesDir, rel);
    await mkdir(dirname(destination), { recursive: true });
    await cp(rel, destination, { recursive: true });
  }

  return artifactDir;
}
