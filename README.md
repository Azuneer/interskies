# 🌌 Interskies

Application web pour afficher une galerie de photos du ciel avec système de commentaires et administration sécurisée.

Application web minimaliste pour afficher et gérer une collection de photos du ciel, avec système de commentaires, upload intégré et administration complète.

- 🖼️ Galerie en mosaïque avec cadres torn/cut
- 🎨 Thème automatique jour/nuit (mode sombre 19h-7h)
- 🔍 Filtres (taille, format, tri)
- 💬 Système de commentaires CRUD complet
- 👤 Administration sécurisée avec authentification et upload
- 📱 Design responsive
- 🔒 Sécurité production (SQLite, sessions, headers)

---

## ✨ Fonctionnalités

- 🖼️ **Galerie en mosaïque** - Layout adaptatif avec effet hover
- 🌙 **Mode jour/nuit automatique** - Bascule à 19h-7h
- 💬 **Système de commentaires** - CRUD complet pour chaque photo
- 🔐 **Authentification sécurisée** - Zone admin avec sessions PHP
- 📤 **Upload de photos** - Interface drag & drop avec barre de progression
- 🎨 **Design indie/goth** - Police Space Mono, palette beige/noir/violet/rose
- 💾 **Base SQLite** - Léger et performant

---

## 🚀 Installation rapide

### Prérequis
- Serveur Debian/Ubuntu
- nginx
- PHP 8.4+ (ou 8.1+)
- Git

### Déploiement en 3 commandes

```bash
# 1. Cloner le projet
git clone https://github.com/votre-repo/interskies.git
cd interskies

# 2. Déployer le serveur complet (nginx + PHP + SSL + fail2ban)
sudo chmod +x deploy_complete.sh
sudo ./deploy_complete.sh

# 3. Configurer l'upload de photos
sudo chmod +x setup_upload_final.sh
sudo ./setup_upload_final.sh
```

**C'est tout !** Le site est accessible sur `https://votre-domaine.com`

---

## 📁 Structure du projet

```
interskies/
├── index.php                  # Page d'accueil (galerie publique)
├── admin.php                  # Interface d'administration
├── login.php                  # Page de connexion
├── auth.php                   # Gestion de l'authentification
├── upload.php                 # Endpoint d'upload de photos
├── api.php                    # API REST pour les commentaires
├── photos/                    # Dossier des photos uploadées
├── database/                  # Base de données SQLite
│   └── interskies.db
├── assets/
│   ├── css/style.css          # Styles indie/goth
│   └── js/
│       ├── script.js          # Script de la galerie
│       ├── admin-page.js      # Script de l'admin
│       └── photo-upload.js    # Gestion de l'upload
├── config/
│   └── database.php           # Configuration DB
└── Scripts de déploiement:
    ├── setup_upload_final.sh  # ⭐ Setup upload (principal)
    ├── deploy_complete.sh     # Déploiement serveur complet
    ├── change_password.sh     # Changer le mot de passe admin
    ├── update_nginx_config.sh # Fix auth nginx
    ├── enable_https.sh        # Activer HTTPS
    └── diagnostic_upload.sh   # Debug upload
```

---

## 🛠️ Scripts de gestion

### `setup_upload_final.sh` ⭐
**Script principal** pour configurer l'upload de photos
```bash
sudo ./setup_upload_final.sh
```
**Ce qu'il fait automatiquement :**
- ✅ Détecte votre installation
- ✅ Configure les permissions (775 sur photos/, propriétaire www-data)
- ✅ Augmente les limites PHP à 20 MB
- ✅ Redémarre PHP-FPM
- ✅ Vérifie que tout fonctionne

### `deploy_complete.sh`
Déploiement serveur complet de A à Z
```bash
sudo ./deploy_complete.sh
```
Installe : nginx, PHP 8.4, fail2ban, UFW, certbot, configure SSL

### `change_password.sh`
Changer le mot de passe administrateur
```bash
# Interactif
sudo ./change_password.sh

# Ou avec arguments
sudo ./change_password.sh admin NouveauMotDePasse
```

### `update_nginx_config.sh`
Corriger la configuration nginx pour l'authentification
```bash
sudo ./update_nginx_config.sh
```
(Permet les POST vers auth.php tout en bloquant les GET)

### `enable_https.sh`
Activer HTTPS avec Let's Encrypt
```bash
sudo ./enable_https.sh
```

### `diagnostic_upload.sh`
Diagnostic complet de l'upload pour debug
```bash
sudo ./diagnostic_upload.sh
```

---

## 📸 Utilisation

### Interface publique
- Accédez à `https://votre-domaine.com`
- Naviguez dans la galerie de photos
- Cliquez sur une photo pour voir en grand
- Ajoutez des commentaires librement

### Interface d'administration

1. **Connexion**
   - URL : `https://votre-domaine.com/admin.php`
   - Identifiants par défaut : `admin` / `admin123`
   - ⚠️ Changez le mot de passe immédiatement !

2. **Uploader des photos**
   - Cliquez sur **"📷 Ajouter des photos"**
   - Glissez-déposez vos photos (ou cliquez pour sélectionner)
   - Formats supportés : **JPG, PNG, GIF, WEBP**
   - Taille max : **20 MB** par photo
   - Upload multiple possible
   - Barre de progression en temps réel

3. **Gérer les commentaires**
   - Modifier ou supprimer les commentaires
   - Ajouter des commentaires en tant qu'admin

4. **Voir les statistiques**
   - Nombre de photos
   - Nombre de commentaires
   - Espace disque utilisé

---

## 🎨 Design & Personnalisation

### Palette de couleurs

**Mode jour :**
- Fond : `#F5E6D3` (beige clair)
- Texte : `#1A1A1A` (noir)
- Accent violet : `#8B458B`
- Accent rose : `#DB7093`

**Mode nuit (19h-7h automatique) :**
- Fond : `#1A1A1A`
- Texte : `#F5E6D3`
- Mêmes accents

### Typographie
- Police principale : [Space Mono](https://fonts.google.com/specimen/Space+Mono) (Google Fonts)
- Style monospace pour un look indie/goth

### Modifier les horaires du mode nuit

Éditez `assets/js/script.js` :
```javascript
function setThemeBasedOnTime() {
    const currentHour = new Date().getHours();
    // Changer les heures ici (défaut: 19h-7h)
    if (currentHour >= 19 || currentHour < 7) {
        document.body.classList.add('dark-mode');
    }
}
```

---

## 🔒 Sécurité

### Mesures implémentées

- ✅ Authentification avec sessions PHP sécurisées
- ✅ Mots de passe hashés avec `password_hash()` (bcrypt)
- ✅ Timeout de session (30 minutes d'inactivité)
- ✅ Validation stricte des uploads (MIME type, extension, taille, `getimagesize()`)
- ✅ Protection CSRF sur les formulaires
- ✅ Content Security Policy (CSP)
- ✅ Headers de sécurité nginx (X-Frame-Options, X-XSS-Protection, etc.)
- ✅ Fail2ban contre les attaques brute-force
- ✅ Accès bloqué aux fichiers sensibles (config/, database/, auth.php GET)
- ✅ Rate limiting nginx
- ✅ Requêtes préparées (protection SQL injection)

### Configuration recommandée en production

```bash
# 1. Changer le mot de passe admin
sudo ./change_password.sh admin VotreMotDePasseSecurise123!

# 2. Vérifier les permissions
ls -la /var/www/votre-domaine/photos
# Doit être: drwxrwxr-x www-data www-data

# 3. Vérifier fail2ban
sudo fail2ban-client status interskies-auth

# 4. Activer les logs détaillés temporairement si nécessaire
# Voir section Dépannage
```

---

## 🐛 Dépannage

### L'upload ne fonctionne pas

**1. Ouvrir la console du navigateur (F12 → Console)**

Vous devriez voir des logs détaillés :
```
🚀 DÉBUT UPLOAD de 1 fichier(s)
📤 1/1: photo.jpg (2.45 MB)
  ➤ Envoi du fichier...
  ← Réponse HTTP: 200 OK
  ✓ Upload réussi!
  📊 Progression: 100%
```

**2. Vérifier les logs PHP**
```bash
sudo tail -100 /var/log/php8.4-fpm.log | grep "UPLOAD.PHP"
```

Logs attendus :
```
=== UPLOAD.PHP START ===
User authenticated: admin
File uploaded: photo.jpg (2458640 bytes)
MIME type detected: image/jpeg
Image validated: 3024x4032
=== UPLOAD.PHP SUCCESS ===
```

**3. Lancer le diagnostic**
```bash
sudo ./diagnostic_upload.sh
```

**4. Vérifier les permissions**
```bash
ls -la photos/
# Doit afficher: drwxrwxr-x www-data www-data
```

**5. Relancer le setup si nécessaire**
```bash
sudo ./setup_upload_final.sh
```

### Erreur 403 sur admin.php après login

C'est un problème d'auth.php bloqué par nginx.

**Solution :**
```bash
sudo ./update_nginx_config.sh
```

### Erreur 413 "Request Entity Too Large"

Photo trop grosse ou limites PHP trop basses.

**Vérifier les limites :**
```bash
php -i | grep upload_max_filesize
php -i | grep post_max_size
```

**Les augmenter :**
```bash
sudo ./setup_upload_final.sh
# Ou manuellement :
sudo nano /etc/php/8.4/fpm/php.ini
# Changer:
# upload_max_filesize = 20M
# post_max_size = 25M
sudo systemctl restart php8.4-fpm
```

### Session expirée en boucle

Problème de cookies. Vérifier :
- Les cookies sont autorisés dans le navigateur
- Le domaine est correct (pas de conflit http/https)
- Pas de cache corrompu (Ctrl+Shift+R pour rafraîchir)

### Les photos ne s'affichent pas

```bash
# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/votre-domaine/photos
sudo chmod 755 /var/www/votre-domaine/photos
sudo chmod 644 /var/www/votre-domaine/photos/*

# Vérifier les logs nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 🔄 Mise à jour du site

```bash
cd /var/www/votre-domaine

# Sauvegarder la base de données
sudo cp database/interskies.db database/interskies.db.backup-$(date +%Y%m%d)

# Mettre à jour le code
sudo git pull origin main

# Relancer le setup upload si nécessaire
sudo ./setup_upload_final.sh

# Recharger PHP-FPM
sudo systemctl reload php8.4-fpm

# Recharger nginx si config modifiée
sudo nginx -t && sudo systemctl reload nginx
```

---

## 📚 Documentation complète

- **[DEPLOYMENT_DEBIAN.md](DEPLOYMENT_DEBIAN.md)** - Guide de déploiement serveur complet (nginx, PHP, SSL, fail2ban)
- **[DEPLOIEMENT_UPLOAD.md](DEPLOIEMENT_UPLOAD.md)** - Documentation détaillée de la fonctionnalité d'upload

---

## 💻 Développement local

### Installation simple

```bash
# 1. Cloner le projet
git clone https://github.com/votre-repo/interskies.git
cd interskies

# 2. Installer PHP et SQLite
# Debian/Ubuntu:
sudo apt install php php-sqlite3

# macOS:
brew install php

# 3. Créer les dossiers
mkdir -p database photos

# 4. Lancer le serveur PHP
php -S localhost:8000
```

Accédez à http://localhost:8000

### API REST

L'API est accessible sur `/api.php` :

```bash
# GET - Récupérer les commentaires d'une photo
curl "https://interskies.com/api.php?action=comments&photo_id=1"

# POST - Ajouter un commentaire
curl -X POST https://interskies.com/api.php \
  -d "action=add_comment&photo_id=1&author=Jean&content=Magnifique!"

# POST - Modifier un commentaire
curl -X POST https://interskies.com/api.php \
  -d "action=update_comment&id=1&content=Nouveau contenu"

# POST - Supprimer un commentaire
curl -X POST https://interskies.com/api.php \
  -d "action=delete_comment&id=1"
```

---

## 📊 Technologies utilisées

- **Backend** : PHP 8.4
- **Base de données** : SQLite 3
- **Serveur web** : nginx
- **Frontend** : Vanilla JavaScript (ES6+)
- **CSS** : CSS3 avec variables custom
- **Sécurité** : fail2ban, Let's Encrypt SSL
- **Fonts** : Space Mono (Google Fonts)

---

## 📝 License

MIT License

---

## 🙏 Remerciements

Projet créé avec ❤️ pour capturer la beauté du ciel.

Police : [Space Mono](https://fonts.google.com/specimen/Space+Mono) par Colophon Foundry

---

**Version:** 1.0.0 - Production Ready
**Dernière mise à jour:** 2025-01-10
**Status:** ✅ Stable
