#!/usr/bin/env bash
set -euo pipefail

main_branch="origin/main"
packages_dir="pkgs"

changed_files=$(git diff --name-only "$main_branch"...HEAD)

changed_packages=""
for file in $changed_files; do
    if [[ "$file" == pkgs/*/* ]]; then
        pkg=$(echo "$file" | cut -d'/' -f2)
        if [[ -d "$packages_dir/$pkg" ]]; then
            changed_packages="$changed_packages $pkg"
        fi
    fi
done

changed_packages=$(echo "$changed_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [[ -z "$changed_packages" ]]; then
    all_packages=$(ls -1 "$packages_dir/" | grep -v bun.nix | tr '\n' ' ')
    changed_packages="$all_packages"
fi

matrix_json="["
for pkg in $changed_packages; do
    matrix_json+="{\"package\": \"$pkg\"},"
done
matrix_json="${matrix_json%,}"
matrix_json+="]"

echo "has_changes=true" >> "$GITHUB_OUTPUT"
echo "matrix={\"include\": $matrix_json}" >> "$GITHUB_OUTPUT"