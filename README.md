# Interskies - Galerie de Photos du Ciel

Application web pour afficher une galerie de photos du ciel avec système de commentaires et administration sécurisée.

## Fonctionnalités

- 🖼️ Galerie en mosaïque avec cadres torn/cut
- 🎨 Thème automatique jour/nuit (mode sombre 19h-7h)
- 🔍 Filtres (taille, format, tri)
- 💬 Système de commentaires CRUD complet
- 👤 Administration sécurisée avec authentification et upload
- 📱 Design responsive
- 🔒 Sécurité production (SQLite, sessions, headers)

## Stack Technique

- **Frontend**: HTML5, CSS3 (variables CSS), JavaScript vanilla
- **Backend**: PHP 8.1+ avec PDO
- **Base de données**: SQLite 3
- **Serveur web**: nginx + PHP-FPM (ou Apache)
- **Sécurité**: Sessions PHP, bcrypt, CSP headers
- **Fonts**: Space Mono (Google Fonts)

## Déploiement Rapide

### Sur Debian/nginx (Production Recommandée)

```bash
# 1. Télécharger le projet sur votre serveur
cd /tmp
git clone https://github.com/votre-repo/interskies.git
cd interskies

# 2. Exécuter le script de déploiement
chmod +x deploy_interskies.sh
sudo ./deploy_interskies.sh
```

Le script installe automatiquement :
- ✅ PHP 8.1+ et extensions (SQLite, FPM, OPcache)
- ✅ Configuration nginx optimisée
- ✅ Base de données SQLite
- ✅ SSL avec Let's Encrypt
- ✅ Fail2ban pour la protection
- ✅ Sauvegardes automatiques

**Guide complet**: Voir [DEPLOYMENT_DEBIAN.md](DEPLOYMENT_DEBIAN.md)

### Sur Apache (Alternative)

Pour Apache, voir [INSTALLATION.md](INSTALLATION.md)

## Développement Local

### Prérequis

- PHP 8.1+
- Extension PDO SQLite (`php-sqlite3`)
- Serveur web (nginx/Apache) ou PHP built-in server

### Installation

```bash
# 1. Cloner le projet
git clone https://github.com/votre-repo/interskies.git
cd interskies

# 2. Installer l'extension SQLite (si nécessaire)
# Debian/Ubuntu:
sudo apt install php-sqlite3

# macOS:
brew install php
# SQLite est généralement inclus

# 3. Créer les dossiers nécessaires
mkdir -p database photos data

# 4. Lancer le serveur de développement
php -S localhost:8000
```

Accédez à http://localhost:8000

### Migration des données JSON existantes

Si vous avez des données dans `data/photos.json` et `data/comments.json` :

```bash
php migrate_to_sqlite.php
```

### Ajouter des photos

Placez vos fichiers images (JPG, PNG, GIF, WEBP) dans le dossier `photos/`.
Elles seront détectées automatiquement au rechargement de la page.

## Utilisation

### Galerie Publique

Accédez à `/` pour voir la galerie avec :
- Filtres par taille (large/medium/small)
- Filtres par format (paysage/portrait/carré)
- Tri (récent, ancien, taille, nom)
- Compteur de commentaires sur chaque photo
- Modal split-screen (photo + commentaires)

### Administration

**URL**: `/admin.php`

**Identifiants par défaut**:
- Utilisateur: `admin`
- Mot de passe: `admin123`

⚠️ **Changez immédiatement le mot de passe en production!**

Fonctionnalités admin :
- Gestion des photos (titre, description, suppression)
- Gestion des commentaires (édition, suppression)
- Déconnexion sécurisée

### API REST

`/api/comments.php`

```bash
# GET - Récupérer les commentaires d'une photo
curl "https://interskies.com/api/comments.php?photo_id=1"

# POST - Ajouter un commentaire
curl -X POST https://interskies.com/api/comments.php \
  -H "Content-Type: application/json" \
  -d '{"photo_id":1,"content":"Magnifique!","author":"Jean"}'

# PUT - Modifier un commentaire
curl -X PUT https://interskies.com/api/comments.php \
  -H "Content-Type: application/json" \
  -d '{"id":1,"content":"Nouveau contenu"}'

# DELETE - Supprimer un commentaire
curl -X DELETE https://interskies.com/api/comments.php \
  -H "Content-Type: application/json" \
  -d '{"id":1}'
```

## Structure du Projet

```
interskies/
├── api/
│   └── comments.php          # API REST pour les commentaires
├── assets/
│   ├── css/
│   │   └── style.css         # Styles indie grunge/goth
│   └── js/
│       ├── script.js         # Galerie et modal
│       └── admin-page.js     # Interface admin
├── config/
│   └── database.php          # Configuration SQLite
├── database/
│   ├── .htaccess            # Protection accès web
│   └── interskies.db        # Base SQLite (généré)
├── photos/                   # Vos photos
├── admin.php                 # Interface d'administration
├── auth.php                  # Système d'authentification
├── index.php                 # Galerie publique
├── login.php                 # Page de connexion
├── nginx.conf                # Configuration nginx
├── deploy_interskies.sh      # Script de déploiement auto
├── DEPLOYMENT_DEBIAN.md      # Guide nginx/Debian
└── INSTALLATION.md           # Guide Apache
```

## Sécurité

### Mesures implémentées

- ✅ Authentification avec sessions sécurisées
- ✅ Mots de passe hachés (bcrypt)
- ✅ Timeout de session (30 minutes)
- ✅ Protection CSRF via headers
- ✅ Content Security Policy
- ✅ Protection XSS, clickjacking
- ✅ Requêtes préparées (SQL injection)
- ✅ Protection des dossiers sensibles
- ✅ Headers de sécurité nginx
- ✅ Fail2ban pour brute force

### Configuration recommandée

```bash
# Changer le mot de passe admin
# Créer change_password.php:
<?php
require_once 'auth.php';
changePassword('admin', 'VotreNouveauMotDePasse123!');
echo "Mot de passe changé";
?>

# Exécuter et supprimer
php change_password.php
rm change_password.php
```

## Performance

### Optimisations incluses

- Compression gzip (nginx)
- Cache navigateur (images: 30 jours, CSS/JS: 7 jours)
- OPcache PHP activé
- Requêtes SQL optimisées avec index
- LEFT JOIN pour compter les commentaires
- Lazy loading des images

## Maintenance

### Sauvegardes

Le script de déploiement configure des sauvegardes automatiques :

```bash
# Emplacement
/root/backups/interskies/

# Fréquence
Tous les jours à 2h (cron)

# Rétention
30 jours

# Manuel
/root/scripts/backup_interskies.sh
```

### Logs

```bash
# nginx
tail -f /var/log/nginx/interskies_access.log
tail -f /var/log/nginx/interskies_error.log

# PHP
tail -f /var/log/php/error.log

# Fail2ban
fail2ban-client status interskies-auth
```

### Mises à jour

```bash
cd /var/www/interskies.com

# Sauvegarder
sudo -u www-data cp database/interskies.db database/interskies.db.backup

# Mettre à jour
sudo -u www-data git pull origin main

# Permissions
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 database photos

# Recharger PHP-FPM
sudo systemctl reload php8.1-fpm
```

## Dépannage

### "could not find driver"

```bash
sudo apt install php-sqlite3
sudo systemctl restart php8.1-fpm
```

### Erreur 502 Bad Gateway

```bash
sudo systemctl status php8.1-fpm
sudo systemctl restart php8.1-fpm
```

### Les photos ne s'affichent pas

```bash
sudo chmod 755 /var/www/interskies.com/photos
sudo chmod 644 /var/www/interskies.com/photos/*
sudo chown -R www-data:www-data /var/www/interskies.com/photos
```

## Personnalisation

### Thème

Éditez `assets/css/style.css` :

```css
:root {
    --bg-primary: #fffef9;      /* Fond clair */
    --text-primary: #2b2b2b;    /* Texte principal */
    --accent-purple: #b8a7d4;   /* Accent violet */
    --accent-pink: #e5989b;     /* Accent rose */
    /* ... */
}
```

### Horaires mode sombre

Éditez `assets/js/script.js` :

```javascript
function setThemeBasedOnTime() {
    const currentHour = new Date().getHours();
    // Modifier les heures ici (défaut: 19h-7h)
    if (currentHour >= 19 || currentHour < 7) {
        document.body.classList.add('dark-mode');
    }
}
```

## Contribution

Les contributions sont bienvenues !

1. Fork le projet
2. Créez une branche (`git checkout -b feature/amelioration`)
3. Commit (`git commit -m 'Ajout fonctionnalité'`)
4. Push (`git push origin feature/amelioration`)
5. Ouvrez une Pull Request

## Licence

MIT License

## Support

- 📖 Documentation: [DEPLOYMENT_DEBIAN.md](DEPLOYMENT_DEBIAN.md)
- 🐛 Issues: https://github.com/votre-repo/interskies/issues

---

**Fait avec ❤️ pour les amoureux du ciel**
