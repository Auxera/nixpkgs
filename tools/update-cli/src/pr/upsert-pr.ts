import { exec } from "../lib/exec";

export async function upsertPr(args: {
  branch: string;
  title: string;
  body: string;
  labels: string[];
}): Promise<number> {
  const existing = await exec([
    "gh",
    "pr",
    "list",
    "--head",
    args.branch,
    "--json",
    "number",
    "--jq",
    ".[0].number // empty",
  ]);

  const numberText = existing.stdout.trim();
  if (numberText.length > 0) {
    await exec(["gh", "pr", "edit", numberText, "--title", args.title, "--body", args.body]);
    for (const label of args.labels) {
      await exec(["gh", "pr", "edit", numberText, "--add-label", label]);
    }
    return Number(numberText);
  }

  const labelArgs = args.labels.flatMap((label) => ["--label", label]);
  await exec([
    "gh",
    "pr",
    "create",
    "--base",
    "main",
    "--head",
    args.branch,
    "--title",
    args.title,
    "--body",
    args.body,
    ...labelArgs,
  ]);

  const created = await exec([
    "gh",
    "pr",
    "list",
    "--head",
    args.branch,
    "--json",
    "number",
    "--jq",
    ".[0].number // empty",
  ]);

  return Number(created.stdout.trim());
}
