#!/usr/bin/env bash
set -euo pipefail

PACKAGES_INPUT="${PACKAGES:-}"
INPUTS_INPUT="${INPUTS:-}"
SYSTEM="${SYSTEM:-x86_64-linux}"

systems=(
  "x86_64-linux"
  "aarch64-linux"
  "aarch64-darwin"
)

runner_for_system() {
  case "$1" in
    x86_64-linux) echo "ubuntu-latest" ;;
    aarch64-linux) echo "ubuntu-24.04-arm" ;;
    aarch64-darwin) echo "macos-14" ;;
    *)
      echo "unsupported system: $1" >&2
      exit 1
      ;;
  esac
}

if [[ -n "${PACKAGES_INPUT}" ]]; then
  mapfile -t package_names < <(tr ' ' '\n' <<<"${PACKAGES_INPUT}" | sed '/^$/d')
else
  mapfile -t package_names < <(ls pkgs | while read -r name; do
    if [[ -x "pkgs/${name}/update.sh" ]]; then
      printf '%s\n' "${name}"
    fi
  done)
fi

if [[ -n "${INPUTS_INPUT}" ]]; then
  mapfile -t input_names < <(tr ' ' '\n' <<<"${INPUTS_INPUT}" | sed '/^$/d')
else
  mapfile -t input_names < <(jq -r '.nodes | keys[] | select(. != "root")' flake.lock)
fi

matrix_items="[]"

for name in "${package_names[@]:-}"; do
  if [[ ! -x "pkgs/${name}/update.sh" ]]; then
    continue
  fi

  selected_system=""
  selected_version=""
  for system in "${systems[@]}"; do
    version="$(nix eval --raw ".#packages.${system}.${name}.version" 2>/dev/null || true)"
    if [[ -z "${version}" ]]; then
      continue
    fi

    selected_system="${system}"
    selected_version="${version}"
    break
  done

  if [[ -z "${selected_system}" ]]; then
    continue
  fi

  matrix_items="$({
    jq -c \
      --arg name "${name}" \
      --arg version "${selected_version}" \
      --arg system "${selected_system}" \
      --arg runs_on "$(runner_for_system "${selected_system}")" \
      '. + [{type:"package",name:$name,current_version:$version,system:$system,runs_on:$runs_on}]' \
      <<<"${matrix_items}"
  })"
done

for name in "${input_names[@]:-}"; do
  current_rev="$(jq -r --arg name "${name}" '.nodes[$name].locked.rev // "unknown"' flake.lock)"
  if [[ "${current_rev}" == "null" ]]; then
    continue
  fi

  matrix_items="$({
    jq -c \
      --arg name "${name}" \
      --arg current_version "${current_rev:0:8}" \
      --arg system "${SYSTEM}" \
      --arg runs_on "$(runner_for_system "${SYSTEM}")" \
      '. + [{type:"flake-input",name:$name,current_version:$current_version,system:$system,runs_on:$runs_on}]' \
      <<<"${matrix_items}"
  })"
done

matrix_json="$(jq -c '{include: .}' <<<"${matrix_items}")"
has_updates="false"
if [[ "$(jq 'length' <<<"${matrix_items}")" -gt 0 ]]; then
  has_updates="true"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'matrix=%s\n' "${matrix_json}"
    printf 'has-updates=%s\n' "${has_updates}"
  } >>"${GITHUB_OUTPUT}"
else
  echo "matrix=${matrix_json}"
  echo "has-updates=${has_updates}"
fi
