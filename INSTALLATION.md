# Installation Guide - Interskies

## Prérequis

### Extensions PHP requises
- PHP 7.4 ou supérieur
- Extension PDO SQLite : `php-sqlite3` ou `php-pdo-sqlite`

### Installation de l'extension SQLite (si nécessaire)

#### Ubuntu/Debian
```bash
sudo apt-get install php-sqlite3
sudo systemctl restart apache2  # ou php-fpm selon votre configuration
```

#### CentOS/RHEL
```bash
sudo yum install php-pdo
sudo systemctl restart httpd
```

#### macOS (avec Homebrew)
```bash
brew install php
# SQLite est généralement inclus par défaut
```

#### Windows (XAMPP/WAMP)
- Éditer `php.ini`
- Décommenter : `extension=pdo_sqlite`
- Redémarrer Apache

### Vérifier l'installation
```bash
php -m | grep -i pdo
# Devrait afficher : PDO, pdo_sqlite
```

## Installation du site

### 1. Cloner le projet
```bash
git clone <votre-repo>
cd interskies
```

### 2. Configuration des permissions
```bash
# Créer le dossier database avec les bonnes permissions
mkdir -p database
chmod 755 database

# Permissions pour le dossier photos
chmod 755 photos
```

### 3. Initialisation de la base de données

La base de données SQLite sera créée automatiquement lors du premier accès au site.

**Si vous avez des données JSON existantes** (data/photos.json, data/comments.json) :
```bash
php migrate_to_sqlite.php
```

Ce script va :
- Créer la base de données SQLite
- Importer les photos depuis `data/photos.json`
- Importer les commentaires depuis `data/comments.json`
- Créer l'utilisateur admin par défaut

### 4. Compte administrateur par défaut

**⚠️ IMPORTANT - SÉCURITÉ ⚠️**

Identifiants par défaut :
- **Utilisateur** : `admin`
- **Mot de passe** : `admin123`

**Changez immédiatement ce mot de passe en production !**

Pour changer le mot de passe, vous pouvez créer un petit script PHP :
```php
<?php
require_once 'auth.php';
changePassword('admin', 'VOTRE_NOUVEAU_MOT_DE_PASSE');
echo "Mot de passe changé avec succès !";
?>
```

### 5. Configuration Apache

Le fichier `.htaccess` est déjà configuré. Assurez-vous que :
- `mod_rewrite` est activé
- `AllowOverride All` est configuré dans votre VirtualHost

```bash
# Activer mod_rewrite
sudo a2enmod rewrite
sudo systemctl restart apache2
```

### 6. Sécurité production

Le fichier `.htaccess` inclut :
- Protection des dossiers `database/` et `data/`
- Headers de sécurité (XSS, CSRF, clickjacking)
- Protection contre les injections SQL basiques
- Compression GZIP
- Cache navigateur

Vérifiez que les modules Apache suivants sont activés :
```bash
sudo a2enmod headers
sudo a2enmod deflate
sudo a2enmod expires
sudo systemctl restart apache2
```

## Structure des dossiers

```
interskies/
├── api/
│   └── comments.php        # API REST pour les commentaires
├── assets/
│   ├── css/
│   │   └── style.css       # Styles indie grunge/goth
│   └── js/
│       ├── script.js       # Scripts galerie
│       └── admin-page.js   # Scripts admin
├── config/
│   └── database.php        # Configuration SQLite
├── database/
│   ├── .htaccess           # Protection accès web
│   └── interskies.db       # Base SQLite (généré automatiquement)
├── data/
│   ├── .htaccess           # Protection accès web
│   ├── photos.json         # Anciennes données (optionnel)
│   └── comments.json       # Anciennes données (optionnel)
├── photos/                 # Vos photos du ciel
│   ├── ciel_bleu.jpg
│   └── ...
├── .htaccess              # Configuration Apache
├── .gitignore
├── admin.php              # Page administration (protégée)
├── auth.php               # Système d'authentification
├── index.php              # Galerie publique
├── login.php              # Page de connexion
└── migrate_to_sqlite.php  # Script de migration (à supprimer après usage)
```

## Utilisation

### Ajouter des photos
1. Placez vos fichiers images (JPG, PNG, GIF, WEBP) dans le dossier `/photos/`
2. Elles seront automatiquement détectées et ajoutées à la base lors du chargement de la page

### Administration
1. Accédez à `/admin.php`
2. Connectez-vous avec vos identifiants
3. Gérez les photos et commentaires

### Mode automatique jour/nuit
Le thème change automatiquement :
- **Mode sombre** : 19h00 - 07h00
- **Mode clair** : 07h00 - 19h00

## Dépannage

### "could not find driver"
L'extension PDO SQLite n'est pas installée. Voir section "Installation de l'extension SQLite" ci-dessus.

### Les photos n'apparaissent pas
- Vérifiez les permissions du dossier `photos/`
- Vérifiez que les extensions sont autorisées (jpg, jpeg, png, gif, webp)
- Consultez les logs Apache/PHP

### Erreur 500 sur la page admin
- Vérifiez que la base de données existe
- Vérifiez les permissions du dossier `database/`
- Vérifiez les logs d'erreur PHP

### Session expirée constamment
Le timeout de session est de 30 minutes par défaut. Modifiez dans `auth.php` :
```php
$timeout = 1800; // 30 minutes (en secondes)
```

## Support

Pour toute question ou problème, créez une issue sur le dépôt GitHub du projet.
