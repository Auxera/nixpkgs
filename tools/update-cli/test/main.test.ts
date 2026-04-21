import { describe, expect, it } from "bun:test";
import { runCli } from "../src/main";

describe("runCli", () => {
  it("returns usage for empty args", async () => {
    const result = await runCli([]);
    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("Usage:");
  });
});
