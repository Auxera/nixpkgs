export async function fetchLatestReleaseTag(owner: string, repo: string): Promise<string> {
  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "auxera-update-cli",
  };

  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  const url = `https://api.github.com/repos/${owner}/${repo}/releases/latest`;
  console.log(`[github-release] fetching ${url}`);

  const response = await fetch(url, {
    headers,
  });

  if (!response.ok) {
    throw new Error(`failed to fetch release for ${owner}/${repo}: ${response.status} ${response.statusText}`);
  }

  const json = (await response.json()) as { tag_name?: string };
  if (!json.tag_name) {
    throw new Error(`missing tag_name in release for ${owner}/${repo}`);
  }

  console.log(`[github-release] ${owner}/${repo} latest release tag: ${json.tag_name}`);
  return json.tag_name;
}
