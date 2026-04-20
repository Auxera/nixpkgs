#!/usr/bin/env bash
set -euo pipefail

artifact_root="${1:-.github/ci/downloaded-artifacts}"

if [[ ! -d "${artifact_root}" ]]; then
  echo "Artifact root not found: ${artifact_root}"
  exit 0
fi

bash .github/ci/validate-update-artifacts.sh "${artifact_root}"

shopt -s nullglob globstar
metadata_files=("${artifact_root}"/**/metadata.json)

if [[ ${#metadata_files[@]} -eq 0 ]]; then
  echo "No update artifacts to process"
  exit 0
fi

mapfile -t groups < <(jq -r '[.type, .name] | @tsv' "${metadata_files[@]}" | sort -u)

if [[ ${#groups[@]} -eq 0 ]]; then
  echo "No update artifacts to process"
  exit 0
fi

for group in "${groups[@]}"; do
  type="${group%%$'\t'*}"
  name="${group#*$'\t'}"

  echo "Processing ${type}/${name}"

  mapfile -t metadata_paths < <(
    jq -r --arg type "${type}" --arg name "${name}" 'select(.type == $type and .name == $name) | input_filename' "${metadata_files[@]}" \
      | sort
  )

  [[ ${#metadata_paths[@]} -eq 0 ]] && continue

  systems_csv="$(jq -sr 'map(.system) | unique | join(", ")' "${metadata_paths[@]}")"
  current_version="$(jq -r '.current_version' "${metadata_paths[0]}")"
  new_version="$(jq -r '.new_version' "${metadata_paths[0]}")"
  changelog="$(jq -sr 'map(.changelog) | map(select(length > 0)) | .[0] // ""' "${metadata_paths[@]}")"

  branch="update/${name}"
  if [[ "${type}" != "package" ]]; then
    branch="update-input/${name}"
  fi

  git checkout main
  git pull --ff-only
  git reset --hard HEAD

  for metadata_path in "${metadata_paths[@]}"; do
    metadata_dir="$(dirname "${metadata_path}")"
    files_dir="${metadata_dir}/files"
    if [[ -d "${files_dir}" ]]; then
      for f in "${files_dir}"/*; do
        [[ -e "$f" ]] || continue
        rel_path="${f#"${files_dir}/"}"
        echo "Copying ${rel_path}"
        cp -a "${f}" "./${rel_path}"
      done
    fi
  done

  if ! git diff --quiet; then
    echo "Changes to commit:"
    git status --short

    if [[ "${type}" == "package" ]]; then
      body="Automated update of ${name} from ${current_version} to ${new_version}."
      body+=$'\n\n'
      body+="Systems: ${systems_csv}."
      title="${name}: ${current_version} -> ${new_version}"
      commit_message="${title}"
      if [[ -n "${changelog}" ]]; then
        commit_message="${commit_message}\n\n${changelog}"
      fi

      BRANCH_OVERRIDE="${branch}" \
      TITLE_OVERRIDE="${title}" \
      BODY_OVERRIDE="${body}" \
      COMMIT_MESSAGE_OVERRIDE="${commit_message}" \
      CHANGELOG_URL="${changelog}" \
      .github/ci/create-pr.sh "${type}" "${name}" "${current_version}" "${new_version}"
    else
      .github/ci/create-pr.sh "${type}" "${name}" "${current_version}" "${new_version}"
    fi
  else
    echo "No changes for ${type}/${name}, skipping PR"
  fi
done