#!/usr/bin/env bash
set -euo pipefail

: "${ARTIFACT_DIR:?ARTIFACT_DIR is required}"
: "${UPDATE_TYPE:?UPDATE_TYPE is required}"
: "${UPDATE_NAME:?UPDATE_NAME is required}"
: "${UPDATE_SYSTEM:?UPDATE_SYSTEM is required}"
: "${UPDATED:?UPDATED is required}"
: "${CURRENT_VERSION:?CURRENT_VERSION is required}"
: "${NEW_VERSION:?NEW_VERSION is required}"

CHANGELOG="${CHANGELOG:-}"
FILES_JSON="${FILES_JSON:-[]}"

mkdir -p "${ARTIFACT_DIR}/files"

jq -n -S \
  --arg type "${UPDATE_TYPE}" \
  --arg name "${UPDATE_NAME}" \
  --arg system "${UPDATE_SYSTEM}" \
  --argjson updated "${UPDATED}" \
  --arg current_version "${CURRENT_VERSION}" \
  --arg new_version "${NEW_VERSION}" \
  --arg changelog "${CHANGELOG}" \
  --argjson files_changed "${FILES_JSON}" \
  '{
    type: $type,
    name: $name,
    system: $system,
    updated: $updated,
    current_version: $current_version,
    new_version: $new_version,
    changelog: $changelog,
    files_changed: $files_changed
  }' >"${ARTIFACT_DIR}/metadata.json"

if [[ "${UPDATED}" != "true" ]]; then
  exit 0
fi

while IFS= read -r file_path; do
  [[ -z "${file_path}" ]] && continue
  if [[ -e "${file_path}" ]]; then
    mkdir -p "${ARTIFACT_DIR}/files/$(dirname "${file_path}")"
    cp -a "${file_path}" "${ARTIFACT_DIR}/files/${file_path}"
  fi
done < <(jq -r '.[]' <<<"${FILES_JSON}")
