#!/usr/bin/env bash
set -euo pipefail

main_branch="origin/main"
packages_dir="pkgs"

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

changed_files=$(git diff --name-only "$main_branch"...HEAD)

changed_packages=()
for file in $changed_files; do
    if [[ "$file" == pkgs/*/* ]]; then
        pkg=$(echo "$file" | cut -d'/' -f2)
        if [[ -d "$packages_dir/$pkg" ]]; then
            changed_packages+=("$pkg")
        fi
    fi
done

if [[ ${#changed_packages[@]} -eq 0 ]]; then
    mapfile -t changed_packages < <(ls -1 "$packages_dir/" | grep -v bun.nix | grep -v default.nix)
fi

unique_packages=($(printf '%s\n' "${changed_packages[@]}" | sort -u))

matrix_items="[]"
for pkg in "${unique_packages[@]}"; do
    for system in "${systems[@]}"; do
        runs_on="$(runner_for_system "$system")"
        matrix_items="$({
            jq -c \
                --arg package "$pkg" \
                --arg system "$system" \
                --arg runs_on "$runs_on" \
                '. + [{package:$package,system:$system,runs_on:$runs_on}]' \
                <<<"$matrix_items"
        })"
    done
done

echo "has-changes=true" >> "$GITHUB_OUTPUT"
echo "matrix={\"include\": $matrix_items}" >> "$GITHUB_OUTPUT"
