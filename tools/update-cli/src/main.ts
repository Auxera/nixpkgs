import { writeGithubOutput } from "./lib/github-output";
import { exec } from "./lib/exec";
import { discoverBuildTargets } from "./commands/discover-build-targets";
import { discoverUpdates, type PackageMeta } from "./commands/discover-updates";
import { applyUpdate } from "./commands/apply-update";
import { computeOutputHash } from "./commands/compute-output-hash";
import { finalizePr } from "./commands/finalize-pr";
import { fetchLatestReleaseTag } from "./upstream/github-release";

export type CliResult = {
  exitCode: number;
  stdout: string;
  stderr: string;
};

const COMMANDS = new Set([
  "discover-build-targets",
  "discover-updates",
  "apply-update",
  "compute-output-hash",
  "finalize-pr",
]);

function usage(): string {
  return [
    "Usage:",
    "  bun tools/update-cli/src/main.ts discover-build-targets",
    "  bun tools/update-cli/src/main.ts discover-updates",
    "  bun tools/update-cli/src/main.ts apply-update",
    "  bun tools/update-cli/src/main.ts compute-output-hash",
    "  bun tools/update-cli/src/main.ts finalize-pr",
  ].join("\n");
}

function parseFlagValue(argv: string[], flag: string): string {
  const index = argv.indexOf(flag);
  if (index === -1 || index + 1 >= argv.length) {
    return "";
  }
  return argv[index + 1] ?? "";
}

function parseBoolFlag(argv: string[], flag: string): boolean {
  return argv.includes(flag);
}

function parseSpaceSeparated(value: string): string[] {
  return value
    .split(" ")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

async function getPackageMetadata(): Promise<PackageMeta[]> {
  const supportedSystems = ["x86_64-linux", "aarch64-linux", "aarch64-darwin"];
  const nixList = supportedSystems.map((s) => `"${s}"`).join(" ");
  const expr = `pkgs: builtins.map (name: let p = pkgs.\${name}; passthru = p.passthru or {}; si = passthru.sourceInfo or {}; supportedSystems = [${nixList}]; meta = p.meta or {}; rawPlatforms = builtins.map (plat: plat.system or plat) (if builtins.isList meta.platforms then meta.platforms else []); platforms = builtins.filter (s: builtins.elem s supportedSystems) rawPlatforms; in { name = name; version = p.version; sourceInfo = si; platforms = if platforms != [] then platforms else supportedSystems; needsOutputHash = passthru.needsOutputHash or false; hasBunNix = passthru.hasBunNix or false; }) (builtins.attrNames pkgs)`;

  const evalResult = await exec([
    "nix",
    "eval",
    "--json",
    ".#packages.x86_64-linux",
    "--apply",
    expr,
  ]);

  if (evalResult.exitCode !== 0) {
    throw new Error(`failed to read package metadata from nix: ${evalResult.stderr}`);
  }

  const raw = JSON.parse(evalResult.stdout) as Array<{
    name: string;
    version: string;
    sourceInfo: { owner?: string; repo?: string };
    platforms: string[];
    needsOutputHash: boolean;
    hasBunNix: boolean;
  }>;

  return raw
    .filter((pkg) => pkg.name !== "default")
    .map((pkg) => ({
      name: pkg.name,
      version: pkg.version,
      sourceInfo: {
        owner: pkg.sourceInfo.owner ?? "",
        repo: pkg.sourceInfo.repo ?? "",
      },
      platforms: pkg.platforms,
      needsOutputHash: pkg.needsOutputHash,
      hasBunNix: pkg.hasBunNix,
    }));
}

async function getLatestPackageVersion(
  name: string,
  sourceInfo: { owner: string; repo: string },
): Promise<string | null> {
  if (!sourceInfo.owner || !sourceInfo.repo) {
    return null;
  }

  const tag = await fetchLatestReleaseTag(sourceInfo.owner, sourceInfo.repo);
  return tag.startsWith("v") ? tag.slice(1) : tag;
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

  if (command === "discover-build-targets") {
    const changedFiles = parseSpaceSeparated(parseFlagValue(argv, "--changed-files"));
    const packageNames = (await getPackageMetadata()).map((p) => p.name);
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
    const hashRefresh = parseBoolFlag(argv, "--hash-refresh");
    const packages = await getPackageMetadata();

    const result = await discoverUpdates({
      selectedPackages,
      hashRefresh,
      packages,
      getLatestVersion: (name) => {
        const pkg = packages.find((p) => p.name === name);
        return pkg ? getLatestPackageVersion(name, pkg.sourceInfo) : Promise.resolve(null);
      },
    });

    const applyMatrix = JSON.stringify(result.apply_matrix);
    const hashMatrix = JSON.stringify(result.hash_matrix);
    const hasUpdates = result.hasUpdates ? "true" : "false";
    writeGithubOutput("apply_matrix", applyMatrix);
    writeGithubOutput("hash_matrix", hashMatrix);
    writeGithubOutput("has-updates", hasUpdates);
    return {
      exitCode: 0,
      stdout: JSON.stringify({
        apply_matrix: result.apply_matrix,
        hash_matrix: result.hash_matrix,
        hasUpdates: result.hasUpdates,
      }),
      stderr: "",
    };
  }

  if (command === "apply-update") {
    const type = parseFlagValue(argv, "--type") as "package" | "flake-input";
    const name = parseFlagValue(argv, "--name");
    const currentVersion = parseFlagValue(argv, "--current-version");
    const latestVersion = parseFlagValue(argv, "--latest-version");
    const hashRefresh = parseBoolFlag(argv, "--hash-refresh");
    const owner = parseFlagValue(argv, "--owner");
    const repo = parseFlagValue(argv, "--repo");
    const systemsNeedingOutputHash = parseSpaceSeparated(
      parseFlagValue(argv, "--systems-needing-output-hash"),
    );
    const hasBunNix = parseFlagValue(argv, "--has-bun-nix") === "true";

    const result = await applyUpdate({
      type,
      name,
      currentVersion,
      latestVersion,
      hashRefresh,
      owner,
      repo,
      systemsNeedingOutputHash,
      hasBunNix,
    });

    writeGithubOutput("updated", result.updated ? "true" : "false");
    writeGithubOutput("new_version", result.newVersion);
    writeGithubOutput("branch", result.branch);

    return {
      exitCode: 0,
      stdout: JSON.stringify(result),
      stderr: "",
    };
  }

  if (command === "compute-output-hash") {
    const name = parseFlagValue(argv, "--name");
    const system = parseFlagValue(argv, "--system");
    const branch = parseFlagValue(argv, "--branch");

    const result = await computeOutputHash({ name, system, branch });

    return {
      exitCode: 0,
      stdout: JSON.stringify(result),
      stderr: "",
    };
  }

  if (command === "finalize-pr") {
    const type = parseFlagValue(argv, "--type") as "package" | "flake-input";
    const name = parseFlagValue(argv, "--name");
    const branch = parseFlagValue(argv, "--branch");
    const currentVersion = parseFlagValue(argv, "--current-version");
    const newVersion = parseFlagValue(argv, "--new-version");
    const hashRefresh = parseBoolFlag(argv, "--hash-refresh");
    const artifactRoot = parseFlagValue(argv, "--artifact-root");
    const autoMerge = parseFlagValue(argv, "--auto-merge") === "true";
    const labels = parseSpaceSeparated(parseFlagValue(argv, "--labels"));

    const prNumber = await finalizePr({
      type,
      name,
      branch,
      currentVersion,
      newVersion,
      hashRefresh,
      artifactRoot,
      autoMerge,
      labels: labels.length > 0 ? labels : ["dependencies", "automated"],
    });

    return {
      exitCode: 0,
      stdout: JSON.stringify({ prNumber }),
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
