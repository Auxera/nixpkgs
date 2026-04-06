#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <package|flake-input> <name>" >&2
  exit 1
fi

type="$1"
name="$2"
system="${SYSTEM:-x86_64-linux}"

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

case "${type}" in
  package)
    if [[ ! -x "pkgs/${name}/update.sh" ]]; then
      echo "missing package updater: pkgs/${name}/update.sh" >&2
      exit 1
    fi

    "pkgs/${name}/update.sh"

    if ! has_changes; then
      write_output "updated" "false"
      exit 0
    fi

    attr=".#packages.${system}.${name}"
    nix build "${attr}" --print-build-logs

    new_version="$(nix eval --raw "${attr}.version")"
    changelog="$(nix eval --raw "${attr}.meta.changelog" 2>/dev/null || true)"

    write_output "updated" "true"
    write_output "new_version" "${new_version}"
    write_output "changelog" "${changelog}"
    ;;

  flake-input)
    nix flake update "${name}"
    nix flake check

    if ! has_changes; then
      write_output "updated" "false"
      exit 0
    fi

    new_rev="$(jq -r --arg name "${name}" '.nodes[$name].locked.rev // "unknown"' flake.lock)"

    write_output "updated" "true"
    write_output "new_version" "${new_rev:0:8}"
    ;;

  *)
    echo "unsupported update type: ${type}" >&2
    exit 1
    ;;
esac
