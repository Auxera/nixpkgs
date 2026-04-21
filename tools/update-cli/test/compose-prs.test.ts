import { describe, expect, it } from "bun:test";
import { groupByUpdateTarget } from "../src/commands/compose-prs";

describe("groupByUpdateTarget", () => {
  it("groups by update type and name", () => {
    const groups = groupByUpdateTarget([
      { type: "package", name: "opencode", system: "x86_64-linux" },
      { type: "package", name: "opencode", system: "aarch64-linux" },
      { type: "flake-input", name: "nixpkgs", system: "x86_64-linux" },
    ]);

    expect(groups).toHaveLength(2);
  });
});
