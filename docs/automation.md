# Automation Workflows

This document describes repository automation based on `tools/update-cli`.

## Commands

- `discover-build-targets`: computes matrix for changed package builds.
- `discover-updates`: computes update matrix for packages and flake inputs.
- `apply-update`: applies one update unit and exports artifact metadata.
- `compose-prs`: groups artifacts and creates/updates pull requests.
- `migrate-hashes`: one-time migration from `hashes.json` to split hash files.

## Source Of Truth

- Package metadata stays in Nix package files.
- Mutable update state is stored in:
  - `pkgs/<name>/source.json`
  - `pkgs/<name>/output-hashes/<system>.txt`

## CI and Publish Flow

- `ci.yml` runs on `pull_request` only.
  - `fmt`
  - `flake-check --all-systems`
  - `test_build` matrix for changed package targets.
- `build.yml` runs on `merge_group` and `workflow_dispatch`.
  - builds changed package targets
  - pushes cache results to Cachix.

## Update Flow

- `update.yml` runs scheduled and on manual dispatch.
- `discover-updates` creates update matrix.
- `apply-update` runs per matrix target and uploads artifacts.
- `compose-prs` creates one PR per update target (`package` or `flake-input`).

## What `upsertPr` and auto-merge do with merge queue

`upsertPr` ensures each update target has one stable branch and one PR. If a PR exists, it updates title/body/labels; otherwise it creates a new PR.

`enable-auto-merge` runs `gh pr merge --auto` with no merge strategy flags. With GitHub merge queue enabled, this does not bypass queue policy. It marks the PR for automatic merge and GitHub handles queue entry after required checks pass.

If workflow input `auto-merge` is `false`, PRs are still created/updated but not auto-merged.
