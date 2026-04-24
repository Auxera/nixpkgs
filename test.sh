FLAKE_EVAL=$(nix eval .#packages --json --quiet 2>/dev/null)
FULL_MATRIX=$(echo "$FLAKE_EVAL" | jq -c '[to_entries[] | .key as $system | .value | to_entries[] | select(.key != "default") | {system: $system, package: .key}]')

if [[ "true" == "true" ]]; then
  CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
  CHANGED_PACKAGES=$(echo "$CHANGED_FILES" | grep -oE '^pkgs/[^/]+' | cut -d/ -f2 | sort -u | tr '\n' ',' | sed 's/,$//')

  if [[ -z "$CHANGED_PACKAGES" ]]; then
    MATRIX="[]"
  else
    CHANGED_PACKAGES_ARR=$(echo "$CHANGED_PACKAGES" | tr ',' '\n' | jq -R . | jq -c -s .)
    MATRIX=$(echo "$FULL_MATRIX" | jq -c --argjson changed "$CHANGED_PACKAGES_ARR" '[.[] | select(.package | IN($changed[]))]')
  fi
else
  MATRIX="$FULL_MATRIX"
fi

echo "package-matrix=$MATRIX"
