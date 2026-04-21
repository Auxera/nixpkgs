import { appendFileSync } from "node:fs";

export function writeGithubOutput(key: string, value: string): void {
  const path = process.env.GITHUB_OUTPUT;
  if (!path) {
    return;
  }
  appendFileSync(path, `${key}=${value}\n`, "utf8");
}
