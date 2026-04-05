# Changelog — BDme

Toutes les modifications notables sont documentées dans ce fichier.
Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

---

## [1.7.1] — 2026-04-05

### Corrigé

- **Fiche BDGest vide au clic** : l'URL Bedetheque est désormais encodée directement dans `bdgest_id` (`bdg:https://...`) — plus besoin de passer `?url=` en query param ; le modal et la page de recherche récupèrent la fiche correctement depuis la collection comme depuis les résultats

---

## [1.7.0] — 2026-04-05

### Ajouté

- **Recherche BDGest / Bedetheque** : intégration native (scraping authentifié) de la plus grande base de données de BD francophones — les identifiants BDGest sont configurables dans l'admin (chiffrés AES-256)
- **Admin — Sources externes** : l'onglet "Sources externes" affiche désormais deux cartes séparées : Google Books (clé API) et BDGest (pseudo + mot de passe) avec modals dédiés
- **Fiche album BDGest** : récupération des données complètes (auteur, dessinateur, éditeur, EAN, synopsis, couverture) via la page album Bedetheque

### Modifié

- **BDGest passe en source interne** : la recherche BDGest n'ouvre plus un onglet externe — les résultats s'affichent directement dans l'app (nécessite un compte BDGest configuré dans l'admin)
- `GET /api/search?source=bdgest` : nouveau paramètre de source, credentials récupérés depuis `bdme_api_keys`
- `GET /api/search/album/:id` : gère les identifiants préfixés `bdg:` (BDGest) en plus des volumeId Google Books

---

## [1.6.0] — 2026-04-04

### Ajouté

- **Choix du moteur de recherche** : liste déroulante à côté de la barre de recherche avec 4 sources :
  - **Google Books** : moteur par défaut, API intégrée in-app
  - **Open Library** : nouveau moteur in-app via l'API openlibrary.org (gratuite, sans clé)
  - **BDGest** : redirige vers bdgest.com dans un nouvel onglet (pas d'API publique)
  - **Amazon** : redirige vers amazon.fr/livres dans un nouvel onglet (pas d'API publique)
- Un message explicatif s'affiche sous la barre pour les sources externes

---

## [1.5.3] — 2026-04-04

### Modifié

- **Tri dans les séries** : à défaut de numéro de tome, les albums sont triés par année de publication croissante (second critère de tri)

---

## [1.5.2] — 2026-04-04

### Ajouté

- **Édition de la série** : dans le modal d'un album, un bouton ✎ permet de modifier manuellement la série — champ texte avec autocomplétion sur les séries existantes de la collection ; laisser vide pour retirer l'album de toute série

---

## [1.5.1] — 2026-04-04

### Corrigé

- **Bouton "Voir plus" absent** : la détection de pages suivantes se basait sur `res.length === 40` — insuffisant car Google Books retourne parfois moins de résultats même quand il en a davantage ; le service retourne désormais `totalItems` et le frontend compare `startIndex + results.length < totalItems` pour afficher le bouton correctement
- **Format de réponse** : `GET /api/search` retourne désormais `{ results, totalItems }` au lieu d'un tableau brut

---

## [1.5.0] — 2026-04-04

### Ajouté

- **Pagination des résultats de recherche** : bouton "Voir plus" affiché sous les résultats quand Google Books en a davantage — charge les 40 suivants (`startIndex`) et les accumule dans la liste ; une nouvelle recherche repart de zéro
- **Nettoyage UI** : références à BDGest retirées du placeholder et des textes de la page de recherche

---

## [1.4.6] — 2026-04-04

### Corrigé

- **Recherche vide** : retrait du filtre `+subject:comics` — le catalogage Google Books est trop hétérogène pour ce filtre ; la recherche est de nouveau sans restriction de sujet

---

## [1.4.5] — 2026-04-04

### Modifié

- **Recherche limitée aux BD/comics** : `+subject:comics` ajouté à chaque requête Google Books — filtre les résultats aux bandes dessinées et comics uniquement ; `langRestrict: 'fr'` retiré pour inclure les comics en anglais, manga, etc.

---

## [1.4.4] — 2026-04-04

### Modifié

- **Changelog réservé aux admins** : le lien "changelog" dans `VersionFooter` n'est affiché que si `profile.role === 'admin'` — invisible pour les utilisateurs standard et sur la page de login

---

## [1.4.3] — 2026-04-04

### Corrigé

- **Modal changelog vide** : l'endpoint `GET /changelog` déplacé sous `GET /api/changelog` pour être correctement proxifié par nginx sur le VPS — le frontend fetche désormais `/api/changelog`

---

## [1.4.2] — 2026-04-04

### Modifié

- **Limite de résultats de recherche** : `maxResults` passé de 20 à 40 (maximum autorisé par l'API Google Books)

---

## [1.4.1] — 2026-04-04

### Corrigé

- **Tri par tome** : à l'intérieur d'un dossier série, les albums sont désormais triés par numéro de tome croissant ; les albums sans tome apparaissent en dernier

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
