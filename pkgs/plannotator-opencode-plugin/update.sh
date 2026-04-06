#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

hashes_file="${script_dir}/hashes.json"
bun_nix_file="${script_dir}/bun.nix"

owner="backnotprop"
repo="plannotator"

current_version="$(jq -r '.version' "${hashes_file}")"
current_output_hash="$(jq -r '.outputHash // ""' "${hashes_file}")"
latest_tag="$(curl -fsSL "https://api.github.com/repos/${owner}/${repo}/releases/latest" | jq -r '.tag_name')"
latest_version="${latest_tag#v}"

if [[ "${current_version}" == "${latest_version}" ]]; then
  echo "${repo} already up to date (${current_version})"
  exit 0
fi

echo "Updating ${repo}: ${current_version} -> ${latest_version}"

archive_url="https://github.com/${owner}/${repo}/archive/refs/tags/v${latest_version}.tar.gz"
base32_hash="$(nix-prefetch-url --type sha256 --unpack "${archive_url}")"
src_hash="$(nix hash convert --hash-algo sha256 "${base32_hash}")"

jq -n \
  --arg version "${latest_version}" \
  --arg hash "${src_hash}" \
  --arg outputHash "${current_output_hash}" \
  '{version:$version,hash:$hash,outputHash:$outputHash}' >"${hashes_file}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
git clone --depth 1 --branch "v${latest_version}" "https://github.com/${owner}/${repo}" "${tmpdir}/src"

nix run --inputs-from "${repo_root}" bun2nix#bun2nix -- \
  --lock-file "${tmpdir}/src/bun.lock" \
  --output-file "${bun_nix_file}"

set +e
build_output="$(nix build .#packages.x86_64-linux.plannotator-opencode-plugin --no-link 2>&1)"
build_status=$?
set -e

if [[ ${build_status} -ne 0 ]]; then
  next_output_hash="$(sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' <<<"${build_output}" | tail -n1)"
  if [[ -z "${next_output_hash}" ]]; then
    printf '%s\n' "${build_output}" >&2
    echo "failed to extract plannotator outputHash" >&2
    exit 1
  fi

  jq --arg outputHash "${next_output_hash}" '.outputHash = $outputHash' "${hashes_file}" >"${hashes_file}.tmp"
  mv "${hashes_file}.tmp" "${hashes_file}"
fi

echo "Updated ${repo} to ${latest_version}"
