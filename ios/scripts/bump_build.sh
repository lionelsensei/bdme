#!/bin/bash
# Incrémente CURRENT_PROJECT_VERSION (le numéro de build) dans project.yml.
# À lancer avant chaque upload TestFlight/App Store — Apple refuse un
# re-upload avec le même numéro de build pour une même MARKETING_VERSION.
set -euo pipefail
cd "$(dirname "$0")/.."

CURRENT=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | grep -oE '[0-9]+')
NEXT=$((CURRENT + 1))

sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT\"/CURRENT_PROJECT_VERSION: \"$NEXT\"/" project.yml

echo "Build $CURRENT -> $NEXT"
