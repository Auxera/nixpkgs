import { exec } from "../lib/exec";

export async function enableAutoMerge(prNumber: number, enabled: boolean): Promise<void> {
  if (!enabled) {
    return;
  }
  await exec(["gh", "pr", "merge", String(prNumber), "--auto"]);
}
