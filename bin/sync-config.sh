#!/usr/bin/env bash
# sync-config.sh — copy a chosen subset of harness/configs/ into a target
# project, without clobbering local edits.
#
# Usage:
#   bin/sync-config.sh <target-project-dir> <laravel|vue|fullstack> [--dry-run]
#
# Behavior:
#   - Copies files into <target>/harness/configs/... (preserving the same
#     relative layout as this repo), so a project's own configs can import
#     the base config with a stable relative path, e.g.:
#       require __DIR__ . '/harness/configs/php/rector-base.php';
#   - Tracks what it last wrote in <target>/.harness-sync-manifest.json
#     (path -> sha256 of the synced content).
#   - Before overwriting an existing destination file:
#       * if a manifest entry exists and the file's current hash matches
#         it, the file is unchanged since the last sync -> back it up to
#         `<file>.bak` and overwrite.
#       * if a manifest entry exists but the hash differs, the file has
#         been locally edited since the last sync -> SKIP with a warning,
#         never clobber.
#       * if no manifest entry exists but the file already exists, it's
#         unmanaged/foreign -> back it up to `<file>.bak`, overwrite, and
#         start tracking it from now on.
#   - New files (no prior existence) are just copied and tracked.
#
# Requires: jq, sha256sum (or shasum on macOS).

set -euo pipefail

usage() {
  echo "Usage: $0 <target-project-dir> <laravel|vue|fullstack> [--dry-run]" >&2
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

target_dir="$1"
stack="$2"
dry_run=false
if [[ "${3:-}" == "--dry-run" ]]; then
  dry_run=true
fi

harness_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="${target_dir}/.harness-sync-manifest.json"

if [[ ! -d "$target_dir" ]]; then
  echo "Error: target directory '$target_dir' does not exist." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

case "$stack" in
  laravel)
    files=(configs/php/pint.json configs/php/rector-base.php)
    ;;
  vue)
    files=(
      configs/js/eslint.config.base.js
      configs/js/prettier.config.base.js
      configs/js/oxlint.config.base.json
    )
    ;;
  fullstack)
    files=(
      configs/php/pint.json
      configs/php/rector-base.php
      configs/js/eslint.config.base.js
      configs/js/prettier.config.base.js
      configs/js/oxlint.config.base.json
    )
    ;;
  *)
    echo "Error: unknown stack '$stack' (expected laravel, vue, or fullstack)." >&2
    usage
    ;;
esac

# Load existing manifest, or start an empty one.
if [[ -f "$manifest_path" ]]; then
  manifest="$(cat "$manifest_path")"
else
  manifest='{}'
fi

synced=0
skipped=0
backed_up=0

for rel in "${files[@]}"; do
  src="${harness_root}/${rel}"
  dest_rel="harness/${rel}"
  dest="${target_dir}/${dest_rel}"

  if [[ ! -f "$src" ]]; then
    echo "Warning: source '$rel' not found in harness repo, skipping." >&2
    continue
  fi

  new_hash="$(sha256_of "$src")"
  prior_hash="$(jq -r --arg k "$dest_rel" '.[$k] // empty' <<<"$manifest")"

  if [[ -f "$dest" ]]; then
    current_hash="$(sha256_of "$dest")"

    if [[ -n "$prior_hash" && "$current_hash" != "$prior_hash" ]]; then
      echo "SKIP (locally edited): $dest_rel — differs from last synced version, not overwriting." >&2
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -z "$prior_hash" ]]; then
      echo "NOTE: $dest_rel exists but isn't tracked yet — backing up before overwrite." >&2
    fi

    if [[ "$current_hash" == "$new_hash" ]]; then
      # Already up to date; nothing to back up or copy, just ensure tracked.
      manifest="$(jq --arg k "$dest_rel" --arg v "$new_hash" '.[$k] = $v' <<<"$manifest")"
      continue
    fi

    if $dry_run; then
      echo "Would back up and update: $dest_rel"
    else
      cp "$dest" "${dest}.bak"
      backed_up=$((backed_up + 1))
    fi
  fi

  if $dry_run; then
    echo "Would sync: $rel -> $dest_rel"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    manifest="$(jq --arg k "$dest_rel" --arg v "$new_hash" '.[$k] = $v' <<<"$manifest")"
  fi
  synced=$((synced + 1))
done

if ! $dry_run; then
  echo "$manifest" | jq '.' > "$manifest_path"
fi

echo
echo "Synced: $synced  Skipped (local edits): $skipped  Backed up: $backed_up"
if [[ $skipped -gt 0 ]]; then
  echo "Some files were skipped because they've been locally edited since the last sync." >&2
  echo "Review the diff manually and re-run after resolving, if you want the update." >&2
fi
