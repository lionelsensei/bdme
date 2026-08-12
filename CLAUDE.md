# BDme — Contexte projet pour Claude

## Vue d'ensemble

**BDme** est une app iOS native de gestion de BDthèque personnelle (SwiftUI). Usage strictement personnel, mono-compte iCloud, utilisable sur plusieurs appareils (iPhone + iPad) en simultané. Interface sombre, épurée, en français.

> Ce projet a pivoté depuis une v1 web (React + Express + Supabase). Le webapp et le backend Supabase ont été retirés ; seul un mini-backend de proxy BDGest subsiste (voir plus bas).

## Architecture

```
ios/            Projet Xcode (généré via xcodegen depuis project.yml) — l'app
server/         Node.js + Express — proxy de recherche BDGest uniquement
CHANGELOG.md
```

Il n'y a plus de base de données distante : la collection est stockée **localement dans iCloud Drive**, dans un dossier `BDme` à la racine (conteneur ubiquity `iCloud.com.lionelarbey.bdme/Documents`). `server/` ne sert plus qu'à faire le pont vers bedetheque.com (scraping authentifié) — l'app iOS l'appelle uniquement pour la source BDGest ; Google Books et Open Library sont interrogés directement depuis l'app.

## App iOS — `ios/`

Généré avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) à partir de `ios/project.yml`. Après toute modification de `project.yml` :

```bash
cd ios && xcodegen generate
```

Le projet Xcode (`BDme.xcodeproj`) est généré (donc gitignoré) — ne pas l'éditer à la main, éditer `project.yml`.

### Structure des sources (`ios/BDme/`)

| Dossier | Contenu |
|---|---|
| `App/` | `BDmeApp.swift` (entrée, rotation backup au lancement), `RootView.swift` (TabView) |
| `DesignSystem/` | `Theme.swift` — portage des tokens de l'ex-`global.css` (couleurs, styles de bouton, badges, pastilles de statut) |
| `Models/` | `Book`, `WishlistItem`, `ReadStatus` — structs `Codable` |
| `Persistence/` | `ICloudContainer` (résolution du dossier iCloud), `FileRepository` (CRUD générique un-fichier-par-objet via `NSFileCoordinator`), `LibraryStore` (ObservableObject central), `BackupManager` (rotation 3 backups au lancement), `ICloudConflictResolver` (résolution basique des conflits multi-appareils), `KeychainStore` (secrets perso) |
| `Networking/` | `GoogleBooksService`, `OpenLibraryService` (appels directs `URLSession`), `BDGestProxyService` (appelle `server/`), `SearchModels` |
| `Features/Collection` | `CollectionPage`, `BookCard`, `BookRow`, `SeriesFolderCard`, `BookDetailModal` |
| `Features/Wishlist` | `WishlistPage` |
| `Features/Search` | `SearchPage`, `SearchResultRow` |
| `Features/Scan` | `ScanSheet`, `BarcodeScannerView` (VisionKit `DataScannerViewController`) |
| `Features/Settings` | `SettingsPage` (clé Google Books, URL + jeton du proxy BDGest) |

### Stockage local iCloud

- Un fichier JSON par album : `BDme/Books/<uuid>.json`. Idem pour la wishlist : `BDme/Wishlist/<uuid>.json`. Ce découpage (plutôt qu'un fichier unique) minimise les collisions de synchronisation iCloud entre appareils : deux appareils qui modifient des albums différents n'entrent jamais en conflit.
- Toutes les I/O passent par `NSFileCoordinator` (`FileRepository`).
- **Backup automatique** : à chaque lancement (`BackupManager.rotateBackupsAtLaunch()`), l'état courant de `Books/` et `Wishlist/` est copié dans `BDme/Backups/backup_1/`, avec rotation `backup_1 → backup_2 → backup_3` (3 générations conservées).
- **Conflits multi-appareils** : `ICloudConflictResolver` détecte les versions conflictuelles (`NSFileVersion`) au chargement et garde la plus récente (pas de vrai merge de champs — acceptable pour un usage perso à 2 appareils).
- Les couvertures ne sont **pas** stockées dans iCloud (poids) : à terme, cache local dans `Caches/`, re-téléchargées depuis `coverURL` si absentes.

### Recherche — 4 sources (`SearchPage`)

| Source | Intégration |
|---|---|
| Google Books | Appel direct `googleapis.com/books/v1` depuis l'app (clé optionnelle en Keychain) |
| Open Library | Appel direct `openlibrary.org/search.json` (gratuit, sans clé) |
| BDGest | Via le proxy `server/` (voir ci-dessous) — scraping authentifié de bedetheque.com |
| Amazon | Ouvre `amazon.fr/s?i=stripbooks` dans Safari (géré côté app, pas de backend) |

`GoogleTitleParser` (dans `SearchModels.swift`) reproduit `parseGoogleTitle` de l'ex-service Node : décompose `"Série - Titre - n°N"` / `"Série - Titre T.N"` / `"Série - Titre"` / `"Titre seul"`.

`bdgestId` : volumeId Google Books, ou `"bdg:<url bedetheque complète>"` pour un résultat BDGest (même convention qu'avant).

### Fiabilité et hors-ligne

- **Enrichissement automatique** (`BookEnricher.swift`) : la recherche en liste ne renvoie pas auteur/dessinateur/résumé (trop coûteux à scraper par résultat côté serveur) — seule la fiche détaillée par album les fournit. `LibraryStore.addBookEnriching()` lance cet enrichissement en tâche de fond juste après l'ajout, sans attendre que l'utilisateur ouvre le détail. `BookDetailModal` garde un filet de sécurité (à l'ouverture) + un bouton "Rafraîchir les infos" manuel si la fiche reste incomplète.
- **Retry + sérialisation** (`RetrySupport.swift`, et `withRetry`/`invalidateSession` côté `server/services/bdgest.js`) : chaque appel BDGest (app et serveur) retente avec backoff exponentiel avant d'abandonner ; `BDGestRequestQueue` sérialise les appels sortants de l'app pour éviter les rafales parallèles vers bedetheque.com (risque de blocage anti-bot).
- **Circuit breaker** (côté serveur, `server/services/bdgest.js`) : après 3 échecs consécutifs (blocage anti-bot/TLS détecté), le circuit s'ouvre et refuse les requêtes suivantes immédiatement (sans toucher le réseau) pendant un temps de repos croissant (5 min → 2h), pour ne pas aggraver un blocage en cours. Se referme dès qu'une requête réussit.
- **Cache hors-ligne** (`LocalCache.swift`, `OfflineCache`) : chaque recherche et fiche album réussie est mise en cache localement (dossier `Caches/`, hors iCloud — données dérivées, pas de sauvegarde nécessaire). En cas d'échec réseau, l'app retombe sur la dernière version connue. Visible/vidable depuis Réglages.
- **Tomes manquants d'une série** : `getSeriesTomes` (serveur) scrape la page série BDGest (`__10000.html`, liste tous les tomes sur une page) ; `BookDetailModal` compare avec la bibliothèque et propose l'ajout rapide des tomes absents.

## Backend — `server/` (proxy BDGest uniquement)

Toute la logique multi-utilisateur, Supabase, et les routes `books`/`wishlist`/`users`/`api-keys` ont été supprimées avec la v1 web. Le serveur ne fait plus que scraper bedetheque.com pour le compte de l'app iOS personnelle.

| Route | Description |
|---|---|
| `GET /health` | Health check |
| `GET /api/search?q=&startIndex=` | Recherche BDGest (scraping) |
| `GET /api/search/album/:id` | Fiche détaillée BDGest (`id` = `bdg:<url>`) |
| `GET /api/search/series/:id` | Tomes d'une série BDGest (`id` = `bdg:<url série>`) — détection de tomes manquants |

Auth : un simple jeton statique (`PROXY_TOKEN` en `.env`), envoyé par l'app en `Authorization: Bearer <token>` — configuré dans Réglages côté app. Pas de Supabase, pas de rôles.

### Deux instances (repli anti-bot)

Deux VPS distincts hébergent chacun une copie indépendante de `server/`, avec le même `PROXY_TOKEN` pour simplifier la config app :

| Instance | Domaine | Serveur web | Chemin |
|---|---|---|---|
| Principale | `bdme.liooonel.fr` | nginx (proxy_pass `/api/`) | `/var/www/bdme` (process pm2 `bdme-api`) |
| Repli | `bdme2.liooonel.fr` | Apache (`mod_proxy`, `ProxyPass /api/`) | `/var/www/bdme2` (process pm2 `bdme2-api`) |

L'app (`BDGestProxyService.candidateBaseURLs()`) essaie l'URL principale (Réglages) puis l'URL de repli en cas d'échec, avant de retomber sur le cache hors-ligne. Chaque instance a son propre circuit breaker indépendant (voir ci-dessous) — un blocage sur l'une n'affecte pas l'autre. bedetheque.com étant derrière Cloudflare, une IP de VPS "neuve" peut être traitée avec méfiance dès le départ (challenge JS/403) indépendamment de tout usage réel — le repli n'est donc pas une garantie absolue, juste une deuxième chance.

Pour redéployer sur l'instance de repli après un `git push` :
```bash
ssh ubuntu@<ip-vps2>
cd /var/www/bdme2 && git pull origin main && cd server && npm install --production && pm2 restart bdme2-api
```

Identifiants bedetheque.com : variables d'env `BDGEST_LOGIN` / `BDGEST_PASSWORD` (voir `server/.env.example`), plus de stockage chiffré en base — un seul utilisateur, un seul VPS.

`server/services/bdgest.js` : login via `bedetheque.com/connect/login` (CSRF + pseudo + password), session cookie cachée 55 min, parsing via attributs Schema.org (`itemprop`), retry avec backoff exponentiel (`withRetry`) sur chaque appel réseau.

### Pourquoi garder ce backend

Le scraping BDGest a été délibérément laissé côté serveur plutôt que porté nativement dans l'app iOS :
- **Risque App Store** : une app distribuée publiquement embarquant du scraping tiers avec identifiants est plus exposée au rejet (guideline 5.2.1) et à la rétro-ingénierie.
- **Réactivité** : un changement du HTML de bedetheque.com se corrige côté serveur sans passer par la revue App Store.
- **Anti-bot** : une IP/UA serveur stable est moins facilement bloquée qu'un client mobile générique.

## Design system

Thème sombre, porté fidèlement depuis l'ex-`client/src/styles/global.css` dans `ios/BDme/DesignSystem/Theme.swift` :
- Accent doré `#e8c97a` / `#c9a84c`, fond `#0f0f11` → `#26262c`
- Police serif pour les titres (`DM Serif Display`), sans-serif pour le corps (`DM Sans`) — **les fichiers de police ne sont pas encore embarqués dans le bundle** (`UIAppFonts` retiré de `project.yml` en attendant), l'app retombe sur les polices système en attendant
- Indicateurs de statut : point vert (lu), doré (en cours), gris (non lu)
- Badges collection (vert) / souhaits (doré)

## Versioning & release TestFlight

Source de vérité : `ios/project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), propagé à `CFBundleShortVersionString`/`CFBundleVersion` via substitution `$(...)` dans `Info.plist`. Affiché dans l'app : Réglages → "Version" (lu dynamiquement depuis le bundle, `AppVersion.display` dans `SettingsPage.swift`).

Scripts dans `ios/scripts/` :
- `bump_build.sh` — incrémente `CURRENT_PROJECT_VERSION` de 1 (à faire avant tout nouvel upload TestFlight, Apple refuse un doublon de numéro de build pour une même version)
- `bump_version.sh [major|minor|patch]` — incrémente `MARKETING_VERSION` (défaut `patch`) et remet le build à 1
- `release.sh [--no-bump]` — pipeline complet : bump build (sauf `--no-bump`), `xcodegen generate`, archive Release, export + upload App Store Connect via la clé API (`ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH`, défauts déjà configurés dans le script)

Workflow type pour une nouvelle version testable :
```bash
cd ios
./scripts/release.sh
git add project.yml && git commit -m "Build X" && git push
```
Le build apparaît ensuite automatiquement dans le groupe TestFlight interne "BDme Internal" (`hasAccessToAllBuilds: true`).

Clé API App Store Connect : `ios/.appstoreconnect_key/AuthKey_NLFDK62899.p8` (gitignorée, rôle Admin, Key ID `NLFDK62899`, Issuer ID `a968ca85-6ead-4737-b01b-c6b81ba9b847`). App Store Connect App ID `6800276979`, bundle ID enregistré `Q8UMUHD7XK` (capacité iCloud activée dessus), Team ID `K52D9XXV9P`.

## Suivi / travaux restants connus

- Ajouter les fichiers `.ttf` DM Serif Display / DM Sans au bundle et réactiver `UIAppFonts` dans `project.yml`
- Icône d'app définitive (actuellement un placeholder généré — rangée de livres aux couleurs du thème, `AppIcon.appiconset/icon-1024.png`)
- Cache disque des couvertures (actuellement re-téléchargées à chaque affichage)
- Import ponctuel de l'ancienne collection Supabase (export JSON → un fichier par album dans `BDme/Books/`)
- Tests réels multi-appareils iCloud (édition simultanée, résolution de conflits) — le simulateur iOS gère mal iCloud Drive, nécessite des devices physiques (deux appareils déjà appairés en local : iPhone "Yopro 17", iPad "YoyoPad (2)")

## Conventions

- Textes de l'interface en **français**.
- Pas de multi-utilisateur, pas de rôles : usage personnel mono-compte iCloud.
- L'app ne parle au backend `server/` que pour la recherche BDGest — tout le reste (Google Books, Open Library, stockage) est local/direct.
