# Guide de Déploiement - Interskies sur Debian/nginx

Ce guide explique comment déployer Interskies sur un serveur Debian avec nginx et PHP-FPM.

## Prérequis

### 1. Serveur de base configuré

Vous devez avoir exécuté le script `deploy-server.sh` qui configure :
- ✅ Debian à jour
- ✅ nginx
- ✅ Fail2ban
- ✅ UFW (firewall)
- ✅ Certbot (Let's Encrypt)

### 2. Domaine configuré

Votre domaine `interskies.com` doit pointer vers l'IP de votre serveur.

## Installation Automatique

### Script d'installation rapide

```bash
# 1. Télécharger le dépôt sur le serveur
cd /tmp
git clone https://github.com/votre-repo/interskies.git
cd interskies

# 2. Rendre le script exécutable
chmod +x deploy_interskies.sh

# 3. Exécuter le script (en tant que root)
sudo ./deploy_interskies.sh
```

Le script va :
- Installer PHP 8.1+ et les extensions requises (SQLite, FPM)
- Configurer nginx pour Interskies
- Déployer l'application dans `/var/www/interskies.com`
- Créer la base de données SQLite
- Configurer les permissions
- Importer vos photos existantes

---

## Installation Manuelle (étape par étape)

Si vous préférez installer manuellement ou comprendre chaque étape :

### Étape 1 : Installation de PHP et extensions

```bash
# Mettre à jour les paquets
sudo apt update

# Installer PHP et les extensions nécessaires
sudo apt install -y \
    php8.1-fpm \
    php8.1-sqlite3 \
    php8.1-cli \
    php8.1-common \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-curl \
    php8.1-gd

# Vérifier l'installation
php -v
php -m | grep -i pdo
php -m | grep -i sqlite

# Démarrer et activer PHP-FPM
sudo systemctl start php8.1-fpm
sudo systemctl enable php8.1-fpm
```

### Étape 2 : Configuration PHP pour production

```bash
# Éditer la configuration PHP-FPM
sudo nano /etc/php/8.1/fpm/php.ini
```

Modifier les paramètres suivants :

```ini
# Sécurité
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php/error.log

# Performance
memory_limit = 256M
max_execution_time = 300
upload_max_filesize = 50M
post_max_size = 50M

# Session
session.cookie_httponly = 1
session.cookie_secure = 1
session.use_strict_mode = 1
session.cookie_samesite = "Strict"
```

Créer le dossier de logs :

```bash
sudo mkdir -p /var/log/php
sudo chown www-data:www-data /var/log/php
```

### Étape 3 : Déployer l'application

```bash
# Créer le dossier de l'application
sudo mkdir -p /var/www/interskies.com
cd /var/www/interskies.com

# Cloner ou copier les fichiers de l'application
# Option A : depuis Git
sudo git clone https://github.com/votre-repo/interskies.git .

# Option B : depuis votre machine locale (utiliser scp)
# scp -r /chemin/local/interskies/* user@interskies.com:/tmp/interskies/
# sudo mv /tmp/interskies/* /var/www/interskies.com/

# Créer les dossiers nécessaires
sudo mkdir -p database photos

# Configurer les permissions
sudo chown -R www-data:www-data /var/www/interskies.com
sudo chmod -R 755 /var/www/interskies.com
sudo chmod -R 775 database photos
```

### Étape 4 : Configuration nginx

Remplacer la configuration nginx par défaut :

```bash
# Copier la configuration Interskies
sudo cp nginx.conf /etc/nginx/sites-available/interskies.com

# Éditer pour ajuster le nom de domaine et le socket PHP-FPM
sudo nano /etc/nginx/sites-available/interskies.com
```

**Modifications à faire dans nginx.conf :**

1. Ligne `server_name` : remplacer par votre domaine
   ```nginx
   server_name interskies.com www.interskies.com;
   ```

2. Ligne `root` : vérifier le chemin
   ```nginx
   root /var/www/interskies.com;
   ```

3. Ligne `fastcgi_pass` : vérifier la version PHP
   ```nginx
   # Vérifier quelle version de PHP est installée
   ls /var/run/php/

   # Ajuster dans nginx.conf (exemple pour PHP 8.1)
   fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
   ```

Activer le site :

```bash
# Désactiver l'ancien site si nécessaire
sudo rm /etc/nginx/sites-enabled/interskies.com

# Activer la nouvelle configuration
sudo ln -s /etc/nginx/sites-available/interskies.com /etc/nginx/sites-enabled/

# Tester la configuration
sudo nginx -t

# Si OK, recharger nginx
sudo systemctl reload nginx
```

### Étape 5 : Initialiser la base de données

```bash
cd /var/www/interskies.com

# Si vous avez des données JSON existantes à migrer
sudo -u www-data php migrate_to_sqlite.php

# Sinon, la base sera créée automatiquement au premier accès
# L'utilisateur admin par défaut sera créé : admin/admin123
```

### Étape 6 : Importer vos photos

```bash
# Copier vos photos dans le dossier photos/
sudo cp /chemin/vers/vos/photos/*.jpg /var/www/interskies.com/photos/

# Ou utiliser scp depuis votre machine locale
# scp vos-photos/*.jpg user@interskies.com:/tmp/
# sudo mv /tmp/*.jpg /var/www/interskies.com/photos/

# Ajuster les permissions
sudo chown www-data:www-data /var/www/interskies.com/photos/*
sudo chmod 644 /var/www/interskies.com/photos/*
```

Les photos seront automatiquement détectées et ajoutées à la base de données lors du prochain chargement de la page.

### Étape 7 : Configurer SSL (HTTPS)

```bash
# Obtenir un certificat SSL avec Let's Encrypt
sudo certbot --nginx -d interskies.com -d www.interskies.com

# Certbot va automatiquement :
# - Générer le certificat
# - Modifier la configuration nginx pour activer HTTPS
# - Configurer le renouvellement automatique

# Vérifier le renouvellement automatique
sudo certbot renew --dry-run
```

### Étape 8 : Sécuriser le compte admin

**⚠️ IMPORTANT - À FAIRE IMMÉDIATEMENT ⚠️**

```bash
# Créer un script temporaire pour changer le mot de passe
sudo nano /var/www/interskies.com/change_password.php
```

Contenu du fichier :

```php
<?php
require_once __DIR__ . '/auth.php';

// CHANGEZ CE MOT DE PASSE !
$nouveau_mot_de_passe = 'VotreMotDePasseSecurise123!@#';

if (changePassword('admin', $nouveau_mot_de_passe)) {
    echo "✓ Mot de passe changé avec succès !\n";
} else {
    echo "✗ Erreur lors du changement du mot de passe\n";
}
?>
```

Exécuter et supprimer :

```bash
# Exécuter le script
sudo -u www-data php /var/www/interskies.com/change_password.php

# SUPPRIMER IMMÉDIATEMENT le script
sudo rm /var/www/interskies.com/change_password.php

# Vérifier qu'il est supprimé
ls /var/www/interskies.com/change_password.php
```

### Étape 9 : Sécurité supplémentaire

```bash
# Supprimer le script de migration (après l'avoir exécuté)
sudo rm /var/www/interskies.com/migrate_to_sqlite.php

# Vérifier les permissions de la base de données
sudo chmod 600 /var/www/interskies.com/database/interskies.db
sudo chown www-data:www-data /var/www/interskies.com/database/interskies.db

# Vérifier que les .htaccess sont bien présents (pour Apache, optionnel)
ls -la /var/www/interskies.com/database/.htaccess
ls -la /var/www/interskies.com/data/.htaccess

# Pour nginx, la protection est dans la config (déjà fait à l'étape 4)
```

### Étape 10 : Configuration Fail2ban pour Interskies

Ajouter une jail spécifique pour Interskies :

```bash
sudo nano /etc/fail2ban/jail.local
```

Ajouter à la fin :

```ini
# Jail Interskies - Tentatives de login admin
[interskies-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/interskies_error.log
failregex = ^.*"POST /login\.php HTTP.*" (401|403).*$
maxretry = 5
findtime = 600
bantime = 3600
```

Redémarrer Fail2ban :

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status interskies-auth
```

---

## Tests et Vérification

### 1. Vérifier PHP-FPM

```bash
# Status du service
sudo systemctl status php8.1-fpm

# Vérifier les erreurs
sudo tail -f /var/log/php8.1-fpm.log
```

### 2. Vérifier nginx

```bash
# Status du service
sudo systemctl status nginx

# Vérifier les logs
sudo tail -f /var/log/nginx/interskies_access.log
sudo tail -f /var/log/nginx/interskies_error.log
```

### 3. Tester l'application

```bash
# Test depuis le serveur
curl -I http://localhost

# Test depuis l'extérieur
curl -I https://interskies.com
```

Accédez à votre site :
- **Galerie publique** : https://interskies.com
- **Page admin** : https://interskies.com/admin.php
- **Login** : https://interskies.com/login.php

### 4. Vérifier la base de données

```bash
# Entrer dans la base SQLite
sudo -u www-data sqlite3 /var/www/interskies.com/database/interskies.db

# Commandes SQLite
.tables                    # Lister les tables
SELECT * FROM users;       # Voir les utilisateurs
SELECT * FROM photos;      # Voir les photos
SELECT * FROM comments;    # Voir les commentaires
.quit                      # Quitter
```

### 5. Tester l'ajout automatique de photos

```bash
# Ajouter une nouvelle photo
sudo cp nouvelle_photo.jpg /var/www/interskies.com/photos/
sudo chown www-data:www-data /var/www/interskies.com/photos/nouvelle_photo.jpg

# Recharger la page - la photo devrait apparaître automatiquement
```

---

## Maintenance

### Sauvegardes

Créer un script de sauvegarde automatique :

```bash
sudo nano /root/scripts/backup_interskies.sh
```

Contenu :

```bash
#!/bin/bash

BACKUP_DIR="/root/backups/interskies"
DATE=$(date +%Y%m%d_%H%M%S)
SITE_DIR="/var/www/interskies.com"

mkdir -p $BACKUP_DIR

# Sauvegarder la base de données
cp $SITE_DIR/database/interskies.db $BACKUP_DIR/interskies_$DATE.db

# Sauvegarder les photos
tar -czf $BACKUP_DIR/photos_$DATE.tar.gz -C $SITE_DIR photos/

# Garder seulement les 30 dernières sauvegardes
find $BACKUP_DIR -name "interskies_*.db" -mtime +30 -delete
find $BACKUP_DIR -name "photos_*.tar.gz" -mtime +30 -delete

echo "Sauvegarde effectuée : $DATE"
```

Rendre exécutable et ajouter au cron :

```bash
sudo chmod +x /root/scripts/backup_interskies.sh

# Ajouter au crontab (tous les jours à 2h)
sudo crontab -e
# Ajouter : 0 2 * * * /root/scripts/backup_interskies.sh
```

### Monitoring

```bash
# Surveiller l'utilisation de la base de données
watch -n 5 'sudo -u www-data sqlite3 /var/www/interskies.com/database/interskies.db "SELECT COUNT(*) FROM photos;"'

# Surveiller les connexions
sudo tail -f /var/log/nginx/interskies_access.log | grep admin.php

# Surveiller Fail2ban
sudo fail2ban-client status nginx-404
sudo fail2ban-client status interskies-auth
```

### Mises à jour de l'application

```bash
# Se placer dans le dossier de l'application
cd /var/www/interskies.com

# Sauvegarder avant mise à jour
sudo -u www-data cp database/interskies.db database/interskies.db.backup

# Mettre à jour depuis Git
sudo -u www-data git pull origin main

# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/interskies.com
sudo chmod -R 755 /var/www/interskies.com
sudo chmod -R 775 database photos

# Recharger PHP-FPM pour vider le cache
sudo systemctl reload php8.1-fpm
```

---

## Dépannage

### Erreur "could not find driver"

```bash
# Vérifier que SQLite est installé
php -m | grep -i pdo
php -m | grep -i sqlite

# Si absent, installer
sudo apt install php8.1-sqlite3

# Redémarrer PHP-FPM
sudo systemctl restart php8.1-fpm
```

### Erreur 502 Bad Gateway

```bash
# Vérifier que PHP-FPM fonctionne
sudo systemctl status php8.1-fpm

# Vérifier les logs
sudo tail -f /var/log/php8.1-fpm.log

# Vérifier le socket
ls -la /var/run/php/php8.1-fpm.sock

# Redémarrer PHP-FPM
sudo systemctl restart php8.1-fpm
```

### Erreur 403 Forbidden

```bash
# Vérifier les permissions
sudo ls -la /var/www/interskies.com

# Corriger les permissions
sudo chown -R www-data:www-data /var/www/interskies.com
sudo chmod -R 755 /var/www/interskies.com
```

### Les photos ne s'affichent pas

```bash
# Vérifier les permissions du dossier photos
sudo ls -la /var/www/interskies.com/photos

# Corriger
sudo chmod 755 /var/www/interskies.com/photos
sudo chmod 644 /var/www/interskies.com/photos/*
sudo chown -R www-data:www-data /var/www/interskies.com/photos
```

### Session expirée constamment

```bash
# Vérifier les permissions du dossier sessions PHP
sudo ls -la /var/lib/php/sessions

# Corriger si nécessaire
sudo chown -R www-data:www-data /var/lib/php/sessions
sudo chmod 700 /var/lib/php/sessions
```

---

## Performance et Optimisation

### OPcache pour PHP

```bash
# Installer OPcache
sudo apt install php8.1-opcache

# Configurer
sudo nano /etc/php/8.1/fpm/conf.d/10-opcache.ini
```

Configuration recommandée :

```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
```

Redémarrer :

```bash
sudo systemctl restart php8.1-fpm
```

### Optimisation nginx

La configuration fournie inclut déjà :
- ✅ Compression gzip
- ✅ Cache des ressources statiques
- ✅ Headers de sécurité
- ✅ Rate limiting

### Monitoring avec htop

```bash
# Installer htop si nécessaire
sudo apt install htop

# Surveiller les ressources
htop

# Filtrer par processus PHP
htop -p $(pgrep -d',' php-fpm)
```

---

## Checklist de déploiement

- [ ] Serveur Debian configuré avec le script de base
- [ ] PHP 8.1+ et SQLite installés
- [ ] Application déployée dans `/var/www/interskies.com`
- [ ] Configuration nginx activée
- [ ] Base de données SQLite créée
- [ ] Mot de passe admin changé ⚠️
- [ ] SSL/TLS configuré avec Let's Encrypt
- [ ] Photos importées
- [ ] Fail2ban configuré
- [ ] Script de sauvegarde automatique créé
- [ ] Tests d'accès effectués (public + admin)
- [ ] Monitoring en place

---

## Support

Pour toute question ou problème :
- Consultez les logs : `/var/log/nginx/` et `/var/log/php/`
- Vérifiez les issues GitHub du projet
- Documentation nginx : https://nginx.org/en/docs/
- Documentation PHP-FPM : https://www.php.net/manual/fr/install.fpm.php

**Bon déploiement ! 🚀**
