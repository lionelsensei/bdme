# Changelog — BDme

Toutes les modifications notables sont documentées dans ce fichier.
Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

---

## [1.4.0] — 2026-04-04

### Ajouté

- **Vue dossiers par série** (`CollectionPage`) : quand le groupement est actif, les séries sont présentées comme des dossiers cliquables plutôt que de simples en-têtes
  - Grille : `SeriesFolderCard` avec effet d'empilement jusqu'à 3 couvertures décalées/pivotées et pastille dorée du nombre d'albums
  - Liste : `SeriesFolderRow` avec première couverture, nom de la série, compte et flèche `›`
  - Clic → drill-down dans la série avec fil d'ariane `← Séries · Nom · N albums`
  - Retour automatique si filtre, recherche ou groupement change

---

## [1.3.1] — 2026-04-04

### Ajouté

- **Lien changelog** : `VersionFooter.jsx` (composant partagé) remplace les textes de version dans `App.jsx` et `LoginPage.jsx` — affiche `vX.Y.Z · changelog` ; un clic ouvre un modal qui fetche et rend le `CHANGELOG.md`
- **Endpoint public `GET /changelog`** : sert le `CHANGELOG.md` en texte brut depuis Express, sans authentification

---

## [1.3.0] — 2026-04-04

### Ajouté

- **Regroupement par série** (`CollectionPage`) : bouton "⊟ Séries" actif par défaut — les albums sont regroupés alphabétiquement par série avec un en-tête et une pastille dorée indiquant le nombre d'albums ; les albums sans série apparaissent en dernier sous "Albums sans série" ; compatible grille et liste, filtres et recherche locale

---

## [1.2.1] — 2026-04-04

### Corrigé

- **Titre Google Books** : `parseGoogleTitle()` décompose désormais le titre brut (`Astérix - Astérix le Gaulois - n°1`) en champs distincts `series`, `title` et `tome` — le modal affiche "Astérix le Gaulois" en titre et "Astérix — Tome 1" en sous-titre
- **Synopsis HTML** : le synopsis est rendu via `dangerouslySetInnerHTML` pour interpréter les balises `<p>`, `<br>`, etc. renvoyées par Google Books

---

## [1.2.0] — 2026-04-04

### Changement majeur

- **Migration source de données** : abandon du scraping BDGest/Bedetheque (fragile, session cookie, sélecteurs CSS cassables) au profit de l'**API officielle Google Books** — REST propre, clé API simple, pas d'authentification par session, couvertures haute qualité

### Ajouté

- `server/services/googlebooks.js` : nouveau service Google Books (recherche texte, ISBN, fiche par volumeId), cache 1 h, mapping complet des champs
- Variable d'environnement `GOOGLE_BOOKS_API_KEY` comme fallback si aucune clé n'est configurée en base
- Admin → "Sources externes" : modal simplifié pour saisir uniquement la clé API Google Books (plus de login/password BDGest)
- Indication dans l'admin que la recherche fonctionne sans clé (quota limité)

### Modifié

- `server/routes/search.js` : utilise `googlebooks.js`, plus de BDGest ; `getApiKey()` consulte `bdme_api_keys` (service=`googlebooks`) puis `GOOGLE_BOOKS_API_KEY`
- `server/routes/apiKeys.js` : suppression de la dépendance `bdgest.invalidateSession`, `login` retiré (inutile pour Google Books)
- `client/src/pages/SearchPage.jsx` : `fetchDetails()` simplifié, plus de query param `?url=`
- `client/src/components/collection/BookCard.jsx` : enrichissement simplifié, appel direct par volumeId
- `bdme_books.bdgest_id` : réutilisé pour stocker le Google Books `volumeId` (pas de migration de schéma)

---

## [1.1.5] — 2026-04-04

### Corrigé

- **502 sur fiche album** : `getAlbumDetails` retourne désormais `null` au lieu de lever une exception quand la page est vide ou inaccessible (URL fallback `/album-{id}.html` invalide pour les anciens albums) — la route répond 404, le modal ignore silencieusement
- **Enrichissement anciens albums** : deux tentatives successives — d'abord via `bdgest_url` si disponible, sinon via une recherche BDGest par titre/série pour retrouver l'URL correcte avant de fetcher la fiche
- **Champs vides normalisés** : `getAlbumDetails` retourne `null` (et non chaîne vide) pour les champs non trouvés par les sélecteurs CSS

---

## [1.1.4] — 2026-04-04

### Corrigé

- **Couverture disparue** : `cover_url` ajouté aux champs autorisés par `PATCH /api/books/:id` et aux champs d'enrichissement du modal — la couverture est désormais récupérée depuis Bedetheque et persistée en base si absente
- **`ean`** : ajouté aux champs patchables côté serveur (manquait dans la liste)
- **Affichage immédiat** : l'enrichissement met à jour l'état local `data` dès la réponse de Bedetheque, sans attendre le round-trip PATCH — le modal affiche auteurs et couverture instantanément
- **Token 401** : `api.js` maintient désormais le token Supabase en cache via `onAuthStateChange`, évitant les race conditions lors du refresh de session

---

## [1.1.3] — 2026-04-04

### Corrigé

- **Fiche album BDGest (502)** : `getAlbumDetails` construisait `/album-{id}.html`, URL inexistante sur Bedetheque — corrigé en propageant le vrai chemin `/BD-...-{id}.html` depuis `parseResults` jusqu'à la route `/api/search/album/:id` via le query param `?url=`
- **`parseResults`** : retourne désormais `bdgest_url` (chemin complet extrait du href de chaque résultat de recherche)
- **`SearchPage`** : `fetchDetails()` passe `bdgest_url` en query param pour que le serveur utilise l'URL correcte
- **`getAlbumDetails`** : accepte un troisième paramètre `albumUrl` ; garde `/album-{id}.html` comme fallback pour les albums existants en base

---

## [1.1.2] — 2026-04-04

### Corrigé

- **Modal album** : enrichissement automatique à l'ouverture pour les albums sans auteurs — si `bdgest_id` est présent et `author`/`illustrator` vides, la fiche BDGest est récupérée silencieusement, les champs manquants sont patchés en base et l'affichage se met à jour sans fermer le modal. Couvre les albums ajoutés avant la version 1.1.1.

---

## [1.1.1] — 2026-04-04

### Corrigé

- **Ajout à la collection** : appel préalable à la fiche détaillée BDGest (`/api/search/album/:id`) avant enregistrement, afin de récupérer scénariste, dessinateur, éditeur, genre, synopsis et EAN — ces données sont absentes des résultats de liste BDGest
- **Ajout à la wishlist** : même correctif pour l'auteur et l'éditeur

---

## [1.1.0] — 2026-04-04

### Modifié

- **Modal album** : remplacement de la liste déroulante du statut de lecture par 3 boutons visuels (Non lu / En cours / Lu), colorés selon le statut, avec sauvegarde immédiate au clic
- **Modal album** : affichage du numéro de tome en grand (police serif) dans les métadonnées
- **Modal album** : détail des auteurs avec distinction scénariste / dessinateur ; label "Auteurs" au pluriel si les deux diffèrent ; auteur unique si scénariste = dessinateur
- **Version** : indicateur `v1.1` affiché discrètement en bas de la page de login et en bas de chaque page authentifiée (opacité 0.7)

---

## [1.0.0] — 2026-04-04



### Ajouté

- **Collection** : affichage grille / liste, filtres par statut de lecture (non lu, en cours, lu), recherche locale dans la collection
- **Recherche BDGest** : proxy serveur vers Bedetheque.com avec authentification par session cookie et cache 1 h ; indicateur visuel si un album est déjà dans la collection ou la wishlist
- **Wishlist** : bloc séparé pour gérer les albums souhaités, avec ajout depuis les résultats de recherche
- **Scanner EAN** : bouton FAB pour scanner un code-barres via la caméra ou saisir un ISBN manuellement
- **Auth Supabase** : connexion par e-mail + mot de passe via Supabase Auth ; accès sur invitation uniquement (pas d'auto-inscription)
- **Rôles** : profils `user` et `admin` ; les routes et l'UI admin sont protégées
- **Admin — Utilisateurs** : liste des comptes, modification du rôle, désactivation
- **Admin — Clés API** : stockage chiffré (AES-256) des identifiants BDGest dans `bdme_api_keys`
- **Design** : thème sombre, typographie DM Serif Display + DM Sans, 100 % responsive (iPhone, iPad, Mac)
- **Backend** : API Express sur VPS OVH avec Helmet, CORS, rate limiting (global + route recherche)
- **Base de données** : schéma Supabase PostgreSQL self-hosted — tables `bdme_users`, `bdme_books`, `bdme_wishlist`, `bdme_api_keys` avec RLS activée
