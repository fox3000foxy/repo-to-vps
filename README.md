# reverse-action — Transformer un repo GitHub en VPS-like gratuit

Ce dépôt transforme un workflow GitHub Actions en **serveur SSH interactif** (un mini-VPS) avec **état persistant** entre les sessions grâce à une branche Git dédiée : **`filesystem`**.

## 🚀 Concept clé : une session tmate qui survit aux runs

GitHub Actions exécute normalement des jobs jetables. Ici, on combine :

- **tmate** pour un shell interactif (SSH + web terminal)
- une **branche Git (`filesystem`)** pour conserver l’état du système de fichiers entre les runs
- un **workflow GitHub Actions** qui restaure l’état, démarre l’accès distant et enregistre les changements

➡️ Le résultat : un environnement distant réutilisable qui peut démarrer d’une session précédente comme sur un VPS.

---

## 🧠 Comment ça marche (architecture simplifiée)

1. **Le workflow démarre** (via dispatch manuel ou planifié).
2. `start-tmate.sh` restaure l’état depuis la branche `filesystem` (si elle existe), ou crée une branche vide.
3. Le script lance `tmate`, affiche les liens SSH/web, et met à jour `README.md`.
4. Pendant la session, toutes les modifications sont automatiquement commit/push sur la branche `filesystem`.

---

## 🗂️ Branche `filesystem` : votre disque persistant

La branche `filesystem` contient l’état actuel de la session : fichiers, installations, configurations, etc.

- Elle est poussée à chaque sauvegarde automatique.
- Le workflow démarre toujours depuis son dernier état.
- Vous pouvez réinitialiser / inspecter cette branche en utilisant Git (`git checkout filesystem`, `git log`, etc.).

### 🧩 Pour remettre la branche `filesystem` à zéro

Vous pouvez forcer la branche `filesystem` à partir d’une autre référence (ex. `main`) :

```bash
# Réinitialiser filesystem depuis main et pousser
git checkout main
git checkout -B filesystem
git push -f origin filesystem
```

---

## 🛠️ Que contient le repo ?

- `./.github/workflows/ssh.yml` : workflow principal qui démarre la session tmate
- `./.github/scripts/start-tmate.sh` : restaure `filesystem` + lance `tmate` + gère les sauvegardes
- `./.github/scripts/update_readme.py` : met à jour ce README avec les liens de session live

---

## 🔐 Attention : sécurité et usage responsable

Ce système ouvre un accès distant à un runner GitHub (privé selon le repo). Ne le partagez pas publiquement, et arrêtez le workflow si vous n’en avez plus besoin.

---

## ✨ En résumé

Ce dépôt transforme un workflow GitHub Actions en un **mini-VPS** :

- accès SSH / Web shell en direct via `tmate`
- persistance d’état via la branche `filesystem`
- restauration simple : la session reprend toujours là où elle s’est arrêtée

Prêt à l’usage pour explorer, développer ou déboguer dans un environnement Linux temporaire qui peut être restauré à tout moment.
