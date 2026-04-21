export const PLATFORMS = [
  { system: "x86_64-linux", runsOn: "ubuntu-latest" },
  { system: "aarch64-linux", runsOn: "ubuntu-24.04-arm" },
  { system: "aarch64-darwin", runsOn: "macos-14" },
] as const;

export type System = (typeof PLATFORMS)[number]["system"];

export const RUNNER_BY_SYSTEM: Record<System, string> = {
  "x86_64-linux": "ubuntu-latest",
  "aarch64-linux": "ubuntu-24.04-arm",
  "aarch64-darwin": "macos-14",
};
