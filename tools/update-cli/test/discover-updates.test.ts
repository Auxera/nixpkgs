import { describe, expect, it } from "bun:test";
import { discoverUpdates, type PackageMeta } from "../src/commands/discover-updates";

const PACKAGES: PackageMeta[] = [
  {
    name: "opencode",
    version: "1.0.0",
    sourceInfo: { owner: "anomalyco", repo: "opencode" },
    platforms: ["x86_64-linux", "aarch64-linux", "aarch64-darwin"],
    needsOutputHash: true,
  },
  {
    name: "superpowers-opencode-plugin",
    version: "5.0.0",
    sourceInfo: { owner: "obra", repo: "superpowers" },
    platforms: ["x86_64-linux", "aarch64-linux", "aarch64-darwin"],
    needsOutputHash: false,
  },
];

describe("discoverUpdates", () => {
  it("builds apply matrix per package and hash matrix per system", async () => {
    const result = await discoverUpdates({
      selectedPackages: [],
      hashRefresh: false,
      packages: PACKAGES,
      getLatestVersion: async (name) =>
        name === "opencode" ? "1.1.0" : "5.1.0",
    });

    expect(result.apply_matrix.include).toHaveLength(3);

    const opencodeApply = result.apply_matrix.include.find((e) => e.name === "opencode")!;
    expect(opencodeApply.latest_version).toBe("1.1.0");
    expect(opencodeApply.branch).toBe("update/opencode");
    expect(opencodeApply.systems_needing_output_hash).toEqual([
      "x86_64-linux",
      "aarch64-linux",
      "aarch64-darwin",
    ]);

    expect(result.hash_matrix.include).toHaveLength(3);
    expect(result.hash_matrix.include[0].name).toBe("opencode");
    expect(result.hash_matrix.include[0].system).toBe("x86_64-linux");
  });

  it("skips packages with no newer version", async () => {
    const result = await discoverUpdates({
      selectedPackages: [],
      hashRefresh: false,
      packages: PACKAGES,
      getLatestVersion: async () => null,
    });

    const packageEntries = result.apply_matrix.include.filter((e) => e.type === "package");
    expect(packageEntries).toHaveLength(0);
    expect(result.hash_matrix.include).toHaveLength(0);
  });

  it("includes all packages in hash-refresh mode regardless of version", async () => {
    const result = await discoverUpdates({
      selectedPackages: [],
      hashRefresh: true,
      packages: PACKAGES,
      getLatestVersion: async (name) =>
        name === "opencode" ? "1.0.0" : "5.0.0",
    });

    const opencodeApply = result.apply_matrix.include.find((e) => e.name === "opencode")!;
    expect(opencodeApply.latest_version).toBe("1.0.0");
  });

  it("includes flake-input entry in apply matrix only", async () => {
    const result = await discoverUpdates({
      selectedPackages: [],
      hashRefresh: false,
      packages: PACKAGES,
      getLatestVersion: async (name) =>
        name === "opencode" ? "1.1.0" : null,
    });

    const flakeEntries = result.apply_matrix.include.filter((e) => e.type === "flake-input");
    expect(flakeEntries).toHaveLength(1);
    expect(flakeEntries[0].name).toBe("flake-inputs");
    expect(flakeEntries[0].branch).toBe("update/flake-inputs");

    const flakeHashEntries = result.hash_matrix.include.filter(
      (e) => e.name === "flake-inputs",
    );
    expect(flakeHashEntries).toHaveLength(0);
  });

  it("no hash matrix entries for packages without output hashes", async () => {
    const result = await discoverUpdates({
      selectedPackages: ["superpowers-opencode-plugin"],
      hashRefresh: false,
      packages: PACKAGES,
      getLatestVersion: async () => "5.1.0",
    });

    const superpowersHash = result.hash_matrix.include.filter(
      (e) => e.name === "superpowers-opencode-plugin",
    );
    expect(superpowersHash).toHaveLength(0);
  });
});
