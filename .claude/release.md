# Process de release — BDme

## Plateforme(s)

iOS via XcodeGen — projet dans `ios/` (`ios/project.yml` → `ios/BDme.xcodeproj`, généré,
gitignoré). Toujours lancer `xcodegen generate` depuis `ios/` après toute modification de
`project.yml`.

## Versioning

Source de vérité : `ios/project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
Propagé à `CFBundleShortVersionString`/`CFBundleVersion` via substitution `$(...)` dans
`Info.plist`.

Scripts (dans `ios/scripts/`) :
- `bump_build.sh` — incrémente `CURRENT_PROJECT_VERSION` de 1. À faire avant tout nouvel
  upload TestFlight (Apple refuse un doublon de build pour une même version).
- `bump_version.sh [major|minor|patch]` (défaut `patch`) — incrémente `MARKETING_VERSION`,
  remet le build à 1. À utiliser seulement pour une nouvelle version fonctionnelle notable,
  pas pour un simple re-upload.

## Signature / notarization

App Store Connect API Key (pas de Developer ID / notarization macOS ici).
Pointeurs :
- Clé : `ios/.appstoreconnect_key/AuthKey_NLFDK62899.p8` (gitignorée)
- Key ID : `NLFDK62899`
- Issuer ID : `a968ca85-6ead-4737-b01b-c6b81ba9b847`
- Team ID : `K52D9XXV9P`
- Bundle ID : `com.lionelarbey.bdme` (App Store Connect App ID `6800276979`, capacité iCloud
  activée)
- Ces valeurs par défaut sont déjà codées en dur dans `release.sh` (avec override possible via
  `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH`) — pas besoin de les repasser en argument.

## Build / upload

Depuis `ios/` :
1. `./scripts/bump_build.sh` (sauf si on relance un upload après échec sans nouveau code :
   `release.sh --no-bump` gère ce cas lui-même).
2. `./scripts/release.sh` — enchaîne : bump build (sauf `--no-bump`), `xcodegen generate`,
   archive Release (`xcodebuild ... archive -allowProvisioningUpdates`), export + upload vers
   App Store Connect via la clé API (`-authenticationKeyPath/-ID/-IssuerID`).

Le build apparaît ensuite automatiquement dans le groupe TestFlight interne
**"BDme Internal"** (`hasAccessToAllBuilds: true` — pas d'étape manuelle de distribution).

## Fichiers de contexte à mettre à jour

- `CHANGELOG.md` — format [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/), **en
  français**, une section `## [X.Y.Z] — YYYY-MM-DD` par version avec sous-sections `### Ajouté
  / Modifié / Corrigé`.
- `CLAUDE.md` § "Suivi / travaux restants connus" (liste à puces) — relire après chaque release
  et proposer de retirer les points résolus par les commits de cette release. Ne pas toucher
  aux autres sections de `CLAUDE.md` sans demande explicite.

## GitHub Release

Activé : **oui** (nouveau — le repo n'avait jusqu'ici que des commits "Build N", pas de tag ni
de release GitHub ; adopté sur le modèle du projet DiplomacyX).
- Convention de tag : `vX.Y.Z` (aligné sur `MARKETING_VERSION`).
- Titre : `BDme X.Y.Z`.
- Style des notes : en français, structuré comme le CHANGELOG (`### Ajouté/Modifié/Corrigé`
  ou une liste à puces simple si peu de changements).
- Assets à attacher : aucun (app distribuée via TestFlight, pas de binaire à joindre).

## Étapes manuelles connues (non automatisées)

Aucune à ce jour — le pipeline BDme est entièrement scriptable (pas de notarization macOS, pas
de cible secondaire à uploader séparément).
