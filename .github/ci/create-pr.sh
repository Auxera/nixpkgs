#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <package|flake-input> <name> <current-version> <new-version>" >&2
  exit 1
fi

type="$1"
name="$2"
current_version="$3"
new_version="$4"

labels="${PR_LABELS:-dependencies,automated}"
auto_merge="${AUTO_MERGE:-false}"
changelog_url="${CHANGELOG_URL:-}"
system="${SYSTEM:-}"

if [[ "${type}" == "package" ]]; then
  if [[ -z "${system}" ]]; then
    echo "SYSTEM must be set for package updates" >&2
    exit 1
  fi
  branch_system="${system//\//-}"
  branch="update/${name}/${branch_system}"
  title="${name} (${system}): ${current_version} -> ${new_version}"
  body="Automated update of ${name} on ${system} from ${current_version} to ${new_version}."
  commit_message="${title}"
  if [[ -n "${changelog_url}" ]]; then
    commit_message="${commit_message}

${changelog_url}"
  fi
else
  branch="update-input/${name}"
  title="flake.lock: update ${name}"
  body="Automated update of flake input ${name}: ${current_version} -> ${new_version}."
  commit_message="${title}

${current_version} -> ${new_version}"
fi

if git ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
  git push origin --delete "${branch}" || true
fi

git checkout -b "${branch}"
git add .
git commit -m "${commit_message}" --signoff
git push -u origin "${branch}"

label_args=()
IFS=',' read -r -a label_items <<<"${labels}"
for label in "${label_items[@]}"; do
  trimmed="$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"${label}")"
  if [[ -n "${trimmed}" ]]; then
    label_args+=("--label" "${trimmed}")
  fi
done

existing_pr="$(gh pr list --head "${branch}" --json number --jq '.[0].number // empty')"

if [[ -n "${existing_pr}" ]]; then
  gh pr edit "${existing_pr}" --title "${title}" --body "${body}"
  pr_number="${existing_pr}"
else
  gh pr create --title "${title}" --body "${body}" --base main --head "${branch}" "${label_args[@]}"
  pr_number="$(gh pr list --head "${branch}" --json number --jq '.[0].number // empty')"
fi

if [[ "${auto_merge}" == "true" && -n "${pr_number}" ]]; then
  gh pr merge "${pr_number}" --squash --auto || true
fi
