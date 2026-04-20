#!/usr/bin/env bash
set -euo pipefail

artifact_root="${1:-.github/ci/downloaded-artifacts}"

shopt -s nullglob globstar
metadata_files=("${artifact_root}"/**/metadata.json)

if [[ ${#metadata_files[@]} -eq 0 ]]; then
  echo "No update artifacts found"
  exit 0
fi

jq -s '
  def required_keys: ["type","name","system","updated","current_version","new_version","changelog","files_changed"];

  if (all(.[]; (required_keys - (keys)) == [])) | not then
    error("artifact missing required keys")
  elif (all(.[]; (.files_changed | type) == "array")) | not then
    error("files_changed must be an array")
  elif ((map([.type, .name, .system] | join("|")) | length) != (map([.type, .name, .system] | join("|")) | unique | length)) then
    error("duplicate artifact type/name/system entries")
  elif (
    [
      (group_by(.type + "|" + .name)[]
        | select(.[0].type == "package")
        | [.[].new_version] | unique | length)
    ]
    | all(. <= 1)
  ) | not then
    error("inconsistent new_version within package artifact group")
  else
    .
  end
' "${metadata_files[@]}" >/dev/null

echo "Update artifact validation passed"
