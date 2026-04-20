#!/usr/bin/env bash
set -euo pipefail

main_branch="origin/main"
packages_dir="pkgs"

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

matrix_json="["
for pkg in "${unique_packages[@]}"; do
    matrix_json+="{\"package\": \"$pkg\"},"
done
matrix_json="${matrix_json%,}"
matrix_json+="]"

echo "has-changes=true" >> "$GITHUB_OUTPUT"
echo "matrix={\"include\": $matrix_json}" >> "$GITHUB_OUTPUT"