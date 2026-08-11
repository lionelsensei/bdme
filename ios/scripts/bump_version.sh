#!/bin/bash
# Incrémente MARKETING_VERSION (major.minor.patch) dans project.yml et
# remet CURRENT_PROJECT_VERSION à 1.
# Usage: bump_version.sh [major|minor|patch]  (défaut: patch)
set -euo pipefail
cd "$(dirname "$0")/.."

PART="${1:-patch}"
CURRENT=$(grep -E '^\s*MARKETING_VERSION:' project.yml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$PART" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Usage: $0 [major|minor|patch]" >&2; exit 1 ;;
esac

NEXT="$MAJOR.$MINOR.$PATCH"
sed -i '' "s/MARKETING_VERSION: \"$CURRENT\"/MARKETING_VERSION: \"$NEXT\"/" project.yml
sed -i '' 's/CURRENT_PROJECT_VERSION: "[0-9]*"/CURRENT_PROJECT_VERSION: "1"/' project.yml

echo "Version $CURRENT -> $NEXT (build repassé à 1)"
