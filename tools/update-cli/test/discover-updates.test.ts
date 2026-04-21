import { describe, expect, it } from "bun:test";
import { discoverUpdates } from "../src/commands/discover-updates";

describe("discoverUpdates", () => {
  it("builds package update matrix from Nix-evaluated package list", async () => {
    const result = await discoverUpdates({
      selectedPackages: ["opencode"],
      selectedInputs: [],
      packageNames: [
        "opencode",
        "plannotator-opencode-plugin",
        "opencode-notifier-plugin",
        "superpowers-opencode-plugin",
      ],
      getCurrentVersion: async () => "1.0.0",
      getLatestVersion: async () => "1.1.0",
      listFlakeInputs: async () => [],
    });

    expect(result.matrix.include).toHaveLength(3);
  });
});
