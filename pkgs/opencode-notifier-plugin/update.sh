#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

hashes_file="${script_dir}/hashes.json"
bun_nix_file="${script_dir}/bun.nix"

owner="mohak34"
repo="opencode-notifier"

supported_systems='["x86_64-linux","aarch64-linux","aarch64-darwin"]'

github_api_opts=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  github_api_opts=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

current_version="$(jq -r '.version' "${hashes_file}")"
latest_tag="$(curl -fsSL "${github_api_opts[@]}" "https://api.github.com/repos/${owner}/${repo}/releases/latest" | jq -r '.tag_name')"
latest_version="${latest_tag#v}"

if [[ "${current_version}" == "${latest_version}" ]]; then
  echo "${repo} already up to date (${current_version})"
  exit 0
fi

echo "Updating ${repo}: ${current_version} -> ${latest_version}"

archive_url="https://github.com/${owner}/${repo}/archive/refs/tags/v${latest_version}.tar.gz"
base32_hash="$(nix-prefetch-url --type sha256 --unpack "${archive_url}")"
src_hash="$(nix hash convert --hash-algo sha256 "${base32_hash}")"

jq \
  --arg version "${latest_version}" \
  --arg hash "${src_hash}" \
  --argjson systems "${supported_systems}" \
  '
    .version = $version
    | .hash = ($systems | map({key: ., value: $hash}) | from_entries)
  ' "${hashes_file}" >"${hashes_file}.tmp"
mv "${hashes_file}.tmp" "${hashes_file}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
git clone --depth 1 --branch "v${latest_version}" "https://github.com/${owner}/${repo}" "${tmpdir}/src"

nix run --inputs-from "${repo_root}" bun2nix#bun2nix -- \
  --lock-file "${tmpdir}/src/bun.lock" \
  --output-file "${bun_nix_file}"

nix run nixpkgs#alejandra -- --quiet "${bun_nix_file}"

echo "Updated ${repo} to ${latest_version}"
