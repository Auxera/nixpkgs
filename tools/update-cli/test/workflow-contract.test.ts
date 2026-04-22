import { describe, expect, it } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const REPO_ROOT = join(import.meta.dir, "..", "..", "..");

describe("workflow contracts", () => {
  it("CI is pull_request-only with non-matrix flake-check and matrix test_build", () => {
    const ci = readFileSync(join(REPO_ROOT, ".github/workflows/ci.yml"), "utf8");
    expect(ci).toContain("pull_request:");
    expect(ci).not.toContain("merge_group:");
    expect(ci).toContain("flake-check:");
    expect(ci).toContain("nix flake check --all-systems");
    expect(ci).toContain("test_build:");
    expect(ci).toContain("matrix:");
  });

  it("build publish includes merge_group", () => {
    const build = readFileSync(join(REPO_ROOT, ".github/workflows/build.yml"), "utf8");
    expect(build).toContain("merge_group:");
  });
});
