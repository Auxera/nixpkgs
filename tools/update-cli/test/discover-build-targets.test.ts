import { describe, expect, it } from "bun:test";
import { discoverBuildTargets } from "../src/commands/discover-build-targets";

describe("discoverBuildTargets", () => {
  it("returns 3 targets for one changed package", () => {
    const result = discoverBuildTargets({
      changedFiles: ["pkgs/opencode/package.nix"],
      packageNames: [
        "opencode",
        "plannotator-opencode-plugin",
        "opencode-notifier-plugin",
        "superpowers-opencode-plugin",
      ],
    });

    expect(result.matrix.include).toHaveLength(3);
  });
});
