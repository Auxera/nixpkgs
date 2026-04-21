export type ArtifactMetadata = {
  type: "package" | "flake-input";
  name: string;
  system: string;
  updated: boolean;
  current_version: string;
  new_version: string;
  changelog: string;
  files_changed: string[];
};

export function validateUpdateArtifacts(items: ArtifactMetadata[]): void {
  const seen = new Set<string>();
  for (const item of items) {
    const key = `${item.type}|${item.name}|${item.system}`;
    if (seen.has(key)) {
      throw new Error(`duplicate artifact: ${key}`);
    }
    seen.add(key);
  }
}
