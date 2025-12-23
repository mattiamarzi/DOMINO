#!/usr/bin/env bash
# clean_repo.sh
#
# Repository hygiene utility for Python projects.
# The script removes common build artifacts, caches, and platform-specific files
# that should not be committed to version control.
#
# Usage:
#   ./tools/clean_repo.sh            # dry-run (prints what would be removed)
#   ./tools/clean_repo.sh --apply    # applies removals
#
# Notes:
# - Tracked files matching the patterns are removed via `git rm -f` to keep the
#   index consistent.
# - Untracked files are removed from the working tree via `rm -rf`.

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" || "${1:-}" == "-y" ]]; then
  DRY_RUN=0
fi

# Ensure we are inside a git repository and move to repo root.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "${REPO_ROOT}"

echo "Repo root: ${REPO_ROOT}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Mode: dry-run (use --apply to actually remove files)."
else
  echo "Mode: apply"
fi

print_action() {
  local action="$1"
  local path="$2"
  printf "%s %s\n" "${action}" "${path}"
}

rm_path() {
  local path="$1"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    print_action "[DRY] rm -rf" "${path}"
  else
    print_action "[DO ] rm -rf" "${path}"
    rm -rf -- "${path}"
  fi
}

git_rm_path() {
  local path="$1"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    print_action "[DRY] git rm -f" "${path}"
  else
    print_action "[DO ] git rm -f" "${path}"
    git rm -f --quiet -- "${path}" || true
  fi
}

# -----------------------------------------------------------------------------
# 1) Remove tracked junk files from git index (and working tree).
# -----------------------------------------------------------------------------
# The patterns below are interpreted as regular expressions over the output of
# `git ls-files`. They are designed to catch typical artifacts that may have
# been accidentally committed.
TRACKED_REGEX=(
  '\.DS_Store$'
  '(^|/)\.pytest_cache($|/)'
  '(^|/)__pycache__($|/)'
  '\.pyc$'
  '\.pyo$'
  '\.pyd$'
  '\.so$'
  '\.dylib$'
  '\.dll$'
  '\.egg-info($|/)'
  '(^|/)build($|/)'
  '(^|/)dist($|/)'
  '(^|/)\.eggs($|/)'
  '(^|/)\.mypy_cache($|/)'
  '(^|/)\.ruff_cache($|/)'
  '(^|/)\.coverage($|/)'
  '(^|/)coverage\.xml$'
  '(^|/)htmlcov($|/)'
)

# Collect tracked paths that match any regex.
TRACKED_TO_REMOVE=()
while IFS= read -r f; do
  for re in "${TRACKED_REGEX[@]}"; do
    if [[ "${f}" =~ ${re} ]]; then
      TRACKED_TO_REMOVE+=("${f}")
      break
    fi
  done
done < <(git ls-files)

if [[ "${#TRACKED_TO_REMOVE[@]}" -gt 0 ]]; then
  echo ""
  echo "Tracked artifacts to remove from git index:"
  for f in "${TRACKED_TO_REMOVE[@]}"; do
    git_rm_path "${f}"
  done
else
  echo ""
  echo "No tracked artifacts detected."
fi

# -----------------------------------------------------------------------------
# 2) Remove untracked artifacts from working tree.
# -----------------------------------------------------------------------------
# This section removes common artifacts even if untracked. It does not rely on
# `.gitignore` and therefore keeps the behavior explicit and reproducible.
echo ""
echo "Removing common untracked artifacts from working tree:"

# Directories.
UNTRACKED_DIR_NAMES=(
  "__pycache__"
  ".pytest_cache"
  ".mypy_cache"
  ".ruff_cache"
  ".eggs"
  "build"
  "dist"
  "htmlcov"
)

for dname in "${UNTRACKED_DIR_NAMES[@]}"; do
  # Find directories with exact name and remove them.
  while IFS= read -r d; do
    rm_path "${d}"
  done < <(find . -type d -name "${dname}" -prune 2>/dev/null || true)
done

# Files.
UNTRACKED_FILE_GLOBS=(
  ".DS_Store"
  "*.pyc"
  "*.pyo"
  "*.pyd"
  ".coverage"
  "coverage.xml"
)

for glob in "${UNTRACKED_FILE_GLOBS[@]}"; do
  # Use find with -name to avoid shell expansion issues.
  while IFS= read -r f; do
    rm_path "${f}"
  done < <(find . -type f -name "${glob}" 2>/dev/null || true)
done

# egg-info directories anywhere (common after local installs/builds).
while IFS= read -r e; do
  rm_path "${e}"
done < <(find . -type d -name "*.egg-info" -prune 2>/dev/null || true)

echo ""
echo "Done."
echo "Tip: run 'git status' to inspect changes."
