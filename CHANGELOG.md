# Changelog — BDme

Toutes les modifications notables sont documentées dans ce fichier.
Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

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
