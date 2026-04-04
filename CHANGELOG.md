# Changelog — BDme

Toutes les modifications notables sont documentées dans ce fichier.
Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

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
