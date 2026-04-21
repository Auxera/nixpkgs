import { describe, expect, it } from "bun:test";
import { parseOutputHashFromBuildLog } from "../src/commands/apply-update";

describe("parseOutputHashFromBuildLog", () => {
  it("extracts got sha256 value", () => {
    const log = "error: hash mismatch\n         got:    sha256-abcDEF123=\n";
    expect(parseOutputHashFromBuildLog(log)).toBe("sha256-abcDEF123=");
  });
});
