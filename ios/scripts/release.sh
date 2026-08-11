#!/bin/bash
# Build, archive et upload vers TestFlight/App Store Connect en une commande.
# Usage:
#   ./scripts/release.sh              incrémente le build, archive, upload
#   ./scripts/release.sh --no-bump    n'incrémente pas le build (ré-upload après un échec)
set -euo pipefail
cd "$(dirname "$0")/.."

KEY_ID="${ASC_KEY_ID:-NLFDK62899}"
ISSUER_ID="${ASC_ISSUER_ID:-a968ca85-6ead-4737-b01b-c6b81ba9b847}"
KEY_PATH="${ASC_KEY_PATH:-$(pwd)/.appstoreconnect_key/AuthKey_${KEY_ID}.p8}"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Clé API introuvable : $KEY_PATH" >&2
  exit 1
fi

if [[ "${1:-}" != "--no-bump" ]]; then
  ./scripts/bump_build.sh
fi

xcodegen generate

rm -rf build/BDme.xcarchive build/export

echo "== Archive =="
xcodebuild -project BDme.xcodeproj -scheme BDme -configuration Release \
  -archivePath build/BDme.xcarchive -destination 'generic/platform=iOS' \
  archive -allowProvisioningUpdates

echo "== Export + upload =="
xcodebuild -exportArchive \
  -archivePath build/BDme.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

VERSION=$(grep -E '^\s*MARKETING_VERSION:' project.yml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
BUILD=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | grep -oE '[0-9]+')
echo "== Terminé : version $VERSION build $BUILD uploadé =="
echo "Pense à committer project.yml (numéro de version/build)."
