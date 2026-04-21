import { migrateHashes } from "./commands/migrate-hashes";

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
