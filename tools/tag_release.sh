#!/usr/bin/env bash
# tools/tag_release.sh
#
# Create and push an annotated git tag for a release.
#
# Usage:
#   ./tools/tag_release.sh v0.1.0
#
# The script assumes:
# - You are in a git repository.
# - You have committed all changes you want included in the release.
# - Your default remote is named "origin".

set -euo pipefail

TAG="${1:-}"
if [[ -z "${TAG}" ]]; then
  echo "Error: missing tag name. Example: ./tools/tag_release.sh v0.1.0"
  exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: not a git repository."; exit 1; }

git status --porcelain | grep -q . && {
  echo "Error: working tree is not clean. Commit or stash changes before tagging."
  git status --porcelain
  exit 1
}

git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${TAG}"

echo "Tagged and pushed: ${TAG}"
