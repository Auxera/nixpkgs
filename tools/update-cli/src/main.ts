import { migrateHashes } from "./commands/migrate-hashes";
import { writeGithubOutput } from "./lib/github-output";
import { exec } from "./lib/exec";
import { discoverBuildTargets } from "./commands/discover-build-targets";
import { discoverUpdates } from "./commands/discover-updates";

export type CliResult = {
  exitCode: number;
  stdout: string;
  stderr: string;
};

const COMMANDS = new Set([
  "migrate-hashes",
  "discover-build-targets",
  "discover-updates",
  "apply-update",
  "compose-prs",
]);

function usage(): string {
  return [
    "Usage:",
    "  bun tools/update-cli/src/main.ts migrate-hashes",
    "  bun tools/update-cli/src/main.ts discover-build-targets",
    "  bun tools/update-cli/src/main.ts discover-updates",
    "  bun tools/update-cli/src/main.ts apply-update",
    "  bun tools/update-cli/src/main.ts compose-prs",
  ].join("\n");
}

function parseFlagValue(argv: string[], flag: string): string {
  const index = argv.indexOf(flag);
  if (index === -1 || index + 1 >= argv.length) {
    return "";
  }
  return argv[index + 1] ?? "";
}

function parseSpaceSeparated(value: string): string[] {
  return value
    .split(" ")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

async function getPackageNamesFromNix(): Promise<string[]> {
  const evalResult = await exec([
    "nix",
    "eval",
    "--json",
    ".#packages.x86_64-linux",
    "--apply",
    "pkgs: builtins.attrNames pkgs",
  ]);

  if (evalResult.exitCode !== 0) {
    throw new Error("failed to read package list from nix");
  }

  const parsed = JSON.parse(evalResult.stdout) as string[];
  return parsed.filter((name) => name !== "default");
}

async function getPackageVersionFromNix(name: string): Promise<string> {
  const evalResult = await exec([
    "nix",
    "eval",
    "--raw",
    `.#packages.x86_64-linux.${name}.version`,
  ]);

  if (evalResult.exitCode !== 0) {
    throw new Error(`failed to read version for ${name}`);
  }

  return evalResult.stdout.trim();
}

async function listFlakeInputs(): Promise<string[]> {
  const evalResult = await exec([
    "nix",
    "eval",
    "--json",
    ".#",
    "--apply",
    "_: builtins.attrNames (builtins.fromJSON (builtins.readFile ./flake.lock).nodes)",
  ]);

  if (evalResult.exitCode !== 0) {
    throw new Error("failed to read flake input names");
  }

  const parsed = JSON.parse(evalResult.stdout) as string[];
  return parsed.filter((name) => name !== "root");
}

export async function runCli(argv: string[]): Promise<CliResult> {
  if (argv.length === 0) {
    return { exitCode: 2, stdout: "", stderr: usage() };
  }

  const command = argv[0];
  if (!COMMANDS.has(command)) {
    return {
      exitCode: 2,
      stdout: "",
      stderr: `Unknown command: ${command}\n${usage()}`,
    };
  }

  if (command === "migrate-hashes") {
    await migrateHashes(process.cwd());
    return {
      exitCode: 0,
      stdout: "migrated hashes files",
      stderr: "",
    };
  }

  if (command === "discover-build-targets") {
    const changedFiles = parseSpaceSeparated(parseFlagValue(argv, "--changed-files"));
    const packageNames = await getPackageNamesFromNix();
    const result = discoverBuildTargets({ changedFiles, packageNames });
    const matrix = JSON.stringify(result.matrix);
    const hasChanges = result.hasChanges ? "true" : "false";
    writeGithubOutput("matrix", matrix);
    writeGithubOutput("has-changes", hasChanges);
    return {
      exitCode: 0,
      stdout: JSON.stringify({ matrix: result.matrix, hasChanges: result.hasChanges }),
      stderr: "",
    };
  }

  if (command === "discover-updates") {
    const selectedPackages = parseSpaceSeparated(parseFlagValue(argv, "--packages"));
    const selectedInputs = parseSpaceSeparated(parseFlagValue(argv, "--inputs"));
    const packageNames = await getPackageNamesFromNix();

    const result = await discoverUpdates({
      selectedPackages,
      selectedInputs,
      packageNames,
      getCurrentVersion: getPackageVersionFromNix,
      getLatestVersion: getPackageVersionFromNix,
      listFlakeInputs,
    });

    const matrix = JSON.stringify(result.matrix);
    const hasUpdates = result.hasUpdates ? "true" : "false";
    writeGithubOutput("matrix", matrix);
    writeGithubOutput("has-updates", hasUpdates);
    return {
      exitCode: 0,
      stdout: JSON.stringify({ matrix: result.matrix, hasUpdates: result.hasUpdates }),
      stderr: "",
    };
  }

  return { exitCode: 0, stdout: `command accepted: ${command}`, stderr: "" };
}

if (import.meta.main) {
  const result = await runCli(process.argv.slice(2));
  if (result.stdout) {
    process.stdout.write(`${result.stdout}\n`);
  }
  if (result.stderr) {
    process.stderr.write(`${result.stderr}\n`);
  }
  process.exit(result.exitCode);
}
