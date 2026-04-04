# BDme — Contexte projet pour Claude

## Vue d'ensemble

**BDme** est une web app de gestion de BDthèque personnelle. L'interface est sombre, épurée et entièrement responsive (iPhone / iPad / Mac). L'accès est sur invitation uniquement (pas d'auto-inscription). Il existe deux rôles : `user` et `admin`.

## Architecture

```
client/         React + Vite (SPA)
server/         Node.js + Express (API REST, déployé sur VPS OVH)
schema.sql      Tables Supabase (PostgreSQL self-hosted)
```

Le backend tourne sur un **VPS OVH** et sert d'intermédiaire entre le frontend et Supabase / Google Books API.

## Stack technique

| Couche        | Technologie                                                  |
|---------------|--------------------------------------------------------------|
| Frontend      | React 18, React Router 6, Vite 5                             |
| Backend       | Node.js, Express 4, Helmet, express-rate-limit               |
| Auth          | Supabase Auth (JWT via header Authorization)                 |
| Base          | Supabase PostgreSQL self-hosted (tables préfixées `bdme_`)   |
| Source externe| Google Books API (REST, pas de scraping)                     |
| Cache         | node-cache (TTL 1 h pour les résultats de recherche)         |
| Crypto        | AES-256 pour la clé API Google Books (stockée admin)         |

## Base de données — tables Supabase

Toutes les tables sont préfixées `bdme_`. RLS activée sur toutes.

| Table            | Description                                               |
|------------------|-----------------------------------------------------------|
| `bdme_users`     | Profil utilisateur + rôle (`user` / `admin`)              |
| `bdme_books`     | Collection BD par utilisateur + statut de lecture         |
| `bdme_wishlist`  | Liste de souhaits par utilisateur                         |
| `bdme_api_keys`  | Clé API Google Books chiffrée (accès admin uniquement)    |

`bdme_books.read_status` : `'unread'` | `'reading'` | `'read'`

`bdme_books.bdgest_id` : contient désormais le **Google Books volumeId** (champ réutilisé, pas de migration nécessaire).

Un trigger `handle_new_user` crée automatiquement la ligne `bdme_users` à chaque nouvel utilisateur Supabase Auth.

## Backend — routes API

Toutes les routes sont protégées par `authMiddleware` (vérification JWT Supabase).

| Route                               | Description                          |
|-------------------------------------|--------------------------------------|
| `GET  /health`                      | Health check                         |
| `GET  /api/changelog`               | CHANGELOG.md en texte brut (public)  |
| `GET/POST/PATCH/DELETE /api/books`  | CRUD collection                      |
| `GET/POST/DELETE /api/wishlist`     | CRUD wishlist                        |
| `GET /api/search?q=&startIndex=`   | Recherche Google Books — retourne `{ results, totalItems }` (pagination) |
| `GET /api/search/isbn/:ean`        | Recherche par EAN/ISBN               |
| `GET /api/search/album/:id`        | Fiche détaillée par volumeId         |
| `GET /api/users`                   | Liste utilisateurs (admin)           |
| `GET/POST/PUT/DELETE /api/api-keys`| Gestion clé Google Books (admin)     |

Rate limiting global : 200 req/15 min. Route `/api/search` : 30 req/min.

### Clé API Google Books

Priorité : `bdme_api_keys` (service=`googlebooks`, champ `encrypted_password`) → variable d'env `GOOGLE_BOOKS_API_KEY`. Sans clé, l'API Google Books fonctionne mais avec un quota limité.

## Source externe — Google Books API

Le service `server/services/googlebooks.js` interroge `https://www.googleapis.com/books/v1` :

- **Recherche** : `GET /volumes?q={query}&maxResults=40&startIndex={n}` (sans filtre de sujet ni `langRestrict`) — pagination via `startIndex`, 40 résultats par page
- **ISBN** : `GET /volumes?q=isbn:{ean}`
- **Fiche** : `GET /volumes/{volumeId}`

Mapping des champs retournés :

| Champ BDme    | Source Google Books                              |
|---------------|--------------------------------------------------|
| `bdgest_id`   | `item.id` (volumeId)                             |
| `title`       | parsé depuis `volumeInfo.title` (voir ci-dessous)|
| `series`      | parsé depuis `volumeInfo.title` (voir ci-dessous)|
| `tome`        | parsé depuis `volumeInfo.title` ou `subtitle`    |
| `author`      | `volumeInfo.authors[0]`                          |
| `illustrator` | `volumeInfo.authors[1]` (si présent)             |
| `publisher`   | `volumeInfo.publisher`                           |
| `year`        | 4 premiers chiffres de `publishedDate`           |
| `genre`       | `volumeInfo.categories[0]`                       |
| `ean`         | `industryIdentifiers` type `ISBN_13` ou `ISBN_10`|
| `cover_url`   | `imageLinks.thumbnail` (zoom=0, HTTPS)           |
| `synopsis`    | `volumeInfo.description` (peut contenir du HTML, rendu via `dangerouslySetInnerHTML`) |

`parseGoogleTitle(rawTitle, subtitle)` décompose le titre Google Books selon ces patterns (par ordre de priorité) :

| Format titre Google Books                  | series            | title                  | tome |
|--------------------------------------------|-------------------|------------------------|------|
| `Série - Titre - n°N`                      | Série             | Titre                  | N    |
| `Série - Titre T.N`                        | Série             | Titre                  | N    |
| `Série - Titre` (sans tome)                | Série             | Titre                  | null |
| `Titre seul`                               | subtitle ou null  | Titre                  | null |

## Frontend — pages

| Route          | Composant         | Accès    |
|----------------|-------------------|----------|
| `/login`       | `LoginPage`       | Public   |
| `/`            | `CollectionPage`  | Auth     |
| `/recherche`   | `SearchPage`      | Auth     |
| `/souhaits`    | `WishlistPage`    | Auth     |
| `/admin`       | `AdminPage`       | Admin    |

Navigation via `Nav.jsx` (burger menu sur mobile). Bouton FAB (`ScanButton.jsx`) pour scanner un EAN ou saisir manuellement un album.

### CollectionPage — regroupement par série

Bouton "⊟ Séries" dans les actions (actif par défaut). Quand activé, les albums sont regroupés alphabétiquement par `series` (tri `localeCompare` français). Les albums sans série apparaissent en dernier sous "Albums sans série". Chaque groupe affiche un `SeriesHeader` avec le nom de la série et une pastille dorée indiquant le nombre d'albums. Le regroupement s'applique aux deux vues (grille et liste) et respecte les filtres de statut et la recherche locale.

**Vue dossiers (navigation deux niveaux) :**
- Quand le groupement est actif et qu'aucun dossier n'est ouvert : les séries sont affichées comme des cartes dossier (`SeriesFolderCard` en grille, `SeriesFolderRow` en liste)
- Grille : effet d'empilement (jusqu'à 3 couvertures décalées et pivotées), pastille dorée avec le nombre d'albums
- Liste : première couverture + nom de la série + nombre d'albums + flèche `›`
- Clic sur un dossier → affiche les albums de cette série triés par numéro de tome croissant (albums sans tome en dernier), avec un fil d'ariane `← Séries · Nom · N albums`
- Retour au dossier : bouton `← Séries` ou changement de filtre/recherche/groupement
- La barre de recherche et les filtres de statut sont masqués quand un dossier est ouvert

### Ajout à la collection / wishlist (`SearchPage.jsx`)

Avant d'enregistrer, `fetchDetails()` appelle `GET /api/search/album/:bdgest_id` pour enrichir les données (Google Books retourne déjà tout dans la recherche, mais l'appel garantit la complétude). La réponse est mise en cache 1 h côté serveur.

### Modal détail album (`BookModal` dans `BookCard.jsx`)

À l'ouverture, si `bdgest_id` est présent et que `author` ou `cover_url` sont vides, le modal appelle `GET /api/search/album/:bdgest_id`, applique immédiatement les données enrichies à l'état local `data`, puis persiste les champs manquants via `PATCH /api/books/:id`.

Champs enrichis : `author`, `illustrator`, `publisher`, `genre`, `synopsis`, `ean`, `cover_url`.

- **Numéro de tome** : affiché en grand (police serif, `#N`) si présent.
- **Auteurs** : scénariste et dessinateur avec mention `(scénario)` / `(dessin)`. Fusionnés si identiques.
- **Statut de lecture** : 3 boutons (Non lu / En cours / Lu), colorés selon le statut, sauvegarde immédiate.
- **Édition de la série** : bouton ✎ à côté du nom de série dans l'en-tête du modal — ouvre un champ texte avec autocomplétion (`datalist`) sur les séries existantes de la collection (prop `allSeries` passée depuis `CollectionPage`) ; laisser vide retire l'album de toute série ; PATCH `/api/books/:id` avec `{ series }`.


## Design system

Thème sombre. Variables CSS dans `client/src/styles/global.css`.

- Accent : `#e8c97a` (doré)
- Fond principal : `#0f0f11`
- Polices : `DM Serif Display` (titres), `DM Sans` (corps)
- Indicateurs de statut : point vert (lu), doré (en cours), gris (non lu)
- Badges : vert `badge-collection`, doré `badge-wishlist`
- Version affichée via `VersionFooter.jsx` (composant unique) en bas de la page de login et de chaque page authentifiée. Affiche `vX.Y.Z` pour tous ; le lien `· changelog` n'est visible que pour les admins (`profile.role === 'admin'`) — un clic ouvre un modal qui fetche `GET /api/changelog` (endpoint public Express) et rend le CHANGELOG.md avec un rendu minimal (titres, puces, séparateurs). La version est à maintenir uniquement dans la constante `VERSION` de `VersionFooter.jsx`.

## Variables d'environnement (serveur)

Voir `server/.env.example` :

```
SUPABASE_URL=
SUPABASE_SERVICE_KEY=
ENCRYPTION_KEY=           # 32 caractères, AES-256
CLIENT_ORIGIN=            # URL du frontend (CORS)
PORT=3001
GOOGLE_BOOKS_API_KEY=     # Fallback si pas de clé en base
```

## Routes API — champs patchables

`PATCH /api/books/:id` accepte : `read_status`, `title`, `series`, `tome`, `author`, `illustrator`, `publisher`, `year`, `genre`, `ean`, `cover_url`, `synopsis`.

## Conventions

- Pas d'auto-inscription : les comptes sont créés manuellement par un admin via Supabase Auth.
- Les rôles sont gérés dans `bdme_users.role`, pas dans Supabase Auth metadata.
- Les textes de l'interface sont en **français**.
- Pas de framework CSS externe — tout est du CSS custom dans `global.css`.
- Le frontend communique exclusivement avec le backend Express (pas d'appels directs à Supabase depuis le client, sauf pour l'auth).
- `bdme_api_keys.encrypted_login` est `null` pour Google Books (pas de login, seulement une clé API).
