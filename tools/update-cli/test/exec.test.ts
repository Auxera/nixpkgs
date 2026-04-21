import { describe, expect, it } from "bun:test";
import { exec } from "../src/lib/exec";

describe("exec", () => {
  it("captures stdout and returns it", async () => {
    const result = await exec(["bash", "-lc", "printf 'hello'"], { stream: true });
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toBe("hello");
  });
});
