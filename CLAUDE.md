# BDme — Contexte projet pour Claude

## Vue d'ensemble

**BDme** est une web app de gestion de BDthèque personnelle. L'interface est sombre, épurée et entièrement responsive (iPhone / iPad / Mac). L'accès est sur invitation uniquement (pas d'auto-inscription). Il existe deux rôles : `user` et `admin`.

## Architecture

```
client/         React + Vite (SPA)
server/         Node.js + Express (API REST, déployé sur VPS OVH)
schema.sql      Tables Supabase (PostgreSQL self-hosted)
```

Le backend tourne sur un **VPS OVH** et sert d'intermédiaire entre le frontend et Supabase / BDGest.

## Stack technique

| Couche     | Technologie                                            |
|------------|--------------------------------------------------------|
| Frontend   | React 18, React Router 6, Vite 5                       |
| Backend    | Node.js, Express 4, Helmet, express-rate-limit         |
| Auth       | Supabase Auth (JWT via cookie ou header)               |
| Base       | Supabase PostgreSQL self-hosted (tables préfixées `bdme_`) |
| Scraping   | axios + cheerio + tough-cookie (BDGest / Bedetheque)   |
| Cache      | node-cache (TTL 1 h pour les résultats de recherche)   |
| Crypto     | AES-256 pour les identifiants BDGest (clés API admin)  |

## Base de données — tables Supabase

Toutes les tables sont préfixées `bdme_`. RLS activée sur toutes.

| Table            | Description                                             |
|------------------|---------------------------------------------------------|
| `bdme_users`     | Profil utilisateur + rôle (`user` / `admin`)            |
| `bdme_books`     | Collection BD par utilisateur + statut de lecture       |
| `bdme_wishlist`  | Liste de souhaits par utilisateur                       |
| `bdme_api_keys`  | Identifiants BDGest chiffrés (accès admin uniquement)   |

`bdme_books.read_status` : `'unread'` | `'reading'` | `'read'`

Un trigger `handle_new_user` crée automatiquement la ligne `bdme_users` à chaque nouvel utilisateur Supabase Auth.

## Backend — routes API

Toutes les routes sont protégées par `authMiddleware` (vérification JWT Supabase).

| Route                  | Description                                      |
|------------------------|--------------------------------------------------|
| `GET  /health`         | Health check                                     |
| `GET/POST/PUT/DELETE /api/books`    | CRUD collection                   |
| `GET/POST/DELETE /api/wishlist`     | CRUD wishlist                     |
| `GET /api/search`      | Recherche BDGest (proxy + cache)                 |
| `GET /api/users`       | Liste utilisateurs (admin)                       |
| `GET/POST/DELETE /api/api-keys`     | Gestion clés BDGest (admin)       |

Rate limiting global : 200 req/15 min. Route `/api/search` : 30 req/min.

## Frontend — pages

| Route          | Composant         | Accès    |
|----------------|-------------------|----------|
| `/login`       | `LoginPage`       | Public   |
| `/`            | `CollectionPage`  | Auth     |
| `/recherche`   | `SearchPage`      | Auth     |
| `/souhaits`    | `WishlistPage`    | Auth     |
| `/admin`       | `AdminPage`       | Admin    |

Navigation via `Nav.jsx` (burger menu sur mobile). Bouton FAB (`ScanButton.jsx`) pour scanner un EAN ou saisir manuellement un album.

### Ajout à la collection / wishlist (`SearchPage.jsx`)

Avant d'enregistrer un album, `SearchPage` appelle `/api/search/album/:bdgest_id?url=...` pour récupérer la fiche complète (auteur, dessinateur, éditeur, genre, synopsis, EAN). Le résultat de la liste BDGest ne contient que titre, série, tome, année et couverture — les auteurs ne sont disponibles que sur la fiche détaillée. La réponse est mise en cache serveur 1 h (`node-cache`).

`parseResults` retourne `bdgest_url` (ex. `/BD-Largo-Winch-Tome-1-L-heritier-212.html`) extrait du href de chaque résultat. Cette URL est passée en query param `?url=` à `getAlbumDetails` pour éviter l'URL construite `/album-{id}.html` qui ne fonctionne pas sur Bedetheque. Pour les albums déjà en base sans cette URL, le fallback `/album-{id}.html` est tenté silencieusement.

### Modal détail album (`BookModal` dans `BookCard.jsx`)

À l'ouverture, si `bdgest_id` est présent mais que `author`/`illustrator` sont vides (albums ajoutés avant le correctif 1.1.1), le modal appelle silencieusement `/api/search/album/:bdgest_id`, patche les champs manquants en base (`author`, `illustrator`, `publisher`, `genre`, `synopsis`, `ean`) via `PATCH /api/books/:id`, et met à jour l'affichage. L'état local `data` (distinct de `book`) permet la mise à jour réactive sans fermer le modal.

- **Numéro de tome** : affiché en grand (police serif, `#N`) si présent.
- **Auteurs** : scénariste et dessinateur affichés séparément avec mention `(scénario)` / `(dessin)`. Si identiques, affiché une seule fois. Label "Auteurs" au pluriel uniquement si les deux diffèrent.
- **Statut de lecture** : 3 boutons côte à côte (Non lu / En cours / Lu) remplaçant la liste déroulante. Le bouton actif est coloré selon le statut (gris / doré / vert). La sauvegarde est immédiate au clic.

## Design system

Thème sombre. Variables CSS dans `client/src/styles/global.css`.

- Accent : `#e8c97a` (doré)
- Fond principal : `#0f0f11`
- Polices : `DM Serif Display` (titres), `DM Sans` (corps)
- Indicateurs de statut : point vert (lu), doré (en cours), gris (non lu)
- Badges : vert `badge-collection`, doré `badge-wishlist`
- Version affichée discrètement (opacité 0.7) en bas de la page de login et en bas de chaque page authentifiée, au format `vX.Y.Z`

## Source externe — BDGest / Bedetheque

Le service `server/services/bdgest.js` scrape `bedetheque.com` :

1. Authentification via le forum BDGest + Bedetheque (session cookie, TTL 1 h)
2. Recherche par titre/série (`RechSerie`)
3. Recherche par EAN/ISBN
4. Fiche album complète (auteur, illustrateur, éditeur, synopsis…)

Les identifiants BDGest sont stockés chiffrés dans `bdme_api_keys` et gérés par l'admin. Sans identifiants, la recherche fonctionne en mode anonyme (résultats limités).

## Variables d'environnement (serveur)

Voir `server/.env.example` :

```
SUPABASE_URL=
SUPABASE_SERVICE_KEY=
ENCRYPTION_KEY=          # 32 caractères, AES-256
CLIENT_ORIGIN=           # URL du frontend (CORS)
PORT=3001
```

## Conventions

- Pas d'auto-inscription : les comptes sont créés manuellement par un admin via Supabase Auth.
- Les rôles sont gérés dans `bdme_users.role`, pas dans Supabase Auth metadata.
- Les textes de l'interface sont en **français**.
- Pas de framework CSS externe — tout est du CSS custom dans `global.css`.
- Le frontend communique exclusivement avec le backend Express (pas d'appels directs à Supabase depuis le client, sauf pour l'auth).
