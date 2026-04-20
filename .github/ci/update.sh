#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <package|flake-input> <name>" >&2
  exit 1
fi

type="$1"
name="$2"
system="${SYSTEM:-x86_64-linux}"
current_version="${CURRENT_VERSION:-unknown}"

write_output() {
  local key="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >>"${GITHUB_OUTPUT}"
  else
    printf '%s=%s\n' "$key" "$value"
  fi
}

has_changes() {
  [[ -n "$(git status --porcelain)" ]]
}

changed_files_json() {
  git status --porcelain | sed 's/^...//' | jq -Rsc 'split("\n") | map(select(length > 0))'
}

export_artifact() {
  local updated="$1"
  local new_version="$2"
  local changelog="$3"
  local files_json="$4"
  local safe_name safe_system artifact_name artifact_dir

  safe_name="${name//\//-}"
  safe_system="${system//\//-}"
  artifact_name="update-${type}-${safe_name}-${safe_system}"
  artifact_dir=".github/ci/artifacts/${artifact_name}"

  ARTIFACT_DIR="${artifact_dir}" \
  UPDATE_TYPE="${type}" \
  UPDATE_NAME="${name}" \
  UPDATE_SYSTEM="${system}" \
  UPDATED="${updated}" \
  CURRENT_VERSION="${current_version}" \
  NEW_VERSION="${new_version}" \
  CHANGELOG="${changelog}" \
  FILES_JSON="${files_json}" \
  bash .github/ci/export-update-artifact.sh

  write_output "artifact_name" "${artifact_name}"
  write_output "artifact_dir" "${artifact_dir}"
}

case "${type}" in
  package)
    if [[ ! -x "pkgs/${name}/update.sh" ]]; then
      echo "missing package updater: pkgs/${name}/update.sh" >&2
      exit 1
    fi

    "pkgs/${name}/update.sh"

    if ! has_changes; then
      write_output "updated" "false"
      export_artifact "false" "${current_version}" "" "[]"
      exit 0
    fi

    attr=".#packages.${system}.${name}"
    nix build "${attr}" --print-build-logs

    new_version="$(nix eval --raw "${attr}.version")"
    changelog="$(nix eval --raw "${attr}.meta.changelog" 2>/dev/null || true)"

    write_output "updated" "true"
    write_output "new_version" "${new_version}"
    write_output "changelog" "${changelog}"
    export_artifact "true" "${new_version}" "${changelog}" "$(changed_files_json)"
    ;;

  flake-input)
    nix flake update "${name}"
    nix flake check

    if ! has_changes; then
      write_output "updated" "false"
      export_artifact "false" "${current_version}" "" "[]"
      exit 0
    fi

    new_rev="$(jq -r --arg name "${name}" '.nodes[$name].locked.rev // "unknown"' flake.lock)"

    write_output "updated" "true"
    write_output "new_version" "${new_rev:0:8}"
    export_artifact "true" "${new_rev:0:8}" "" "$(changed_files_json)"
    ;;

  *)
    echo "unsupported update type: ${type}" >&2
    exit 1
    ;;
esac
