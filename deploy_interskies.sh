#!/bin/bash

################################################################################
# Script de Déploiement Interskies
################################################################################
# Déploie l'application PHP Interskies sur un serveur Debian/nginx
# Prérequis: serveur configuré avec le script deploy-server.sh
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

print_step "🚀 Déploiement Interskies - Galerie Photos du Ciel"

################################################################################
# COLLECTE DES INFORMATIONS
################################################################################

print_step "📋 Collecte des informations"

read -p "Nom de domaine (défaut: interskies.com): " DOMAIN
DOMAIN=${DOMAIN:-interskies.com}

read -p "Email pour Let's Encrypt: " LETSENCRYPT_EMAIL

# Détecter la version PHP disponible
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "")

if [ -z "$PHP_VERSION" ]; then
    print_warning "PHP n'est pas installé. Installation de PHP 8.1..."
    PHP_VERSION="8.1"
else
    print_success "PHP $PHP_VERSION détecté"
fi

echo ""
print_warning "RÉSUMÉ:"
echo "  - Domaine: $DOMAIN"
echo "  - Email: $LETSENCRYPT_EMAIL"
echo "  - Version PHP: $PHP_VERSION"
echo "  - Dossier web: /var/www/$DOMAIN"
echo ""
read -p "Continuer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

WEB_ROOT="/var/www/$DOMAIN"

################################################################################
# 1. INSTALLATION PHP ET EXTENSIONS
################################################################################

print_step "1️⃣  Installation de PHP et extensions"

# Installer PHP si nécessaire
if ! command -v php &> /dev/null; then
    apt-get update
    apt-get install -y software-properties-common
fi

# Installer PHP et extensions
apt-get install -y \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-opcache

print_success "PHP ${PHP_VERSION} et extensions installés"

################################################################################
# 2. CONFIGURATION PHP POUR PRODUCTION
################################################################################

print_step "2️⃣  Configuration PHP"

PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

# Backup de la config originale
if [ ! -f "${PHP_INI}.backup" ]; then
    cp "$PHP_INI" "${PHP_INI}.backup"
fi

# Appliquer les configurations de sécurité
sed -i 's/^expose_php = On/expose_php = Off/' "$PHP_INI"
sed -i 's/^display_errors = On/display_errors = Off/' "$PHP_INI"
sed -i 's/^;log_errors = On/log_errors = On/' "$PHP_INI"
sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
sed -i 's/^;session.cookie_httponly =/session.cookie_httponly = 1/' "$PHP_INI"
sed -i 's/^session.cookie_httponly = .*/session.cookie_httponly = 1/' "$PHP_INI"

# Configuration OPcache
OPCACHE_INI="/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"
cat > "$OPCACHE_INI" << 'EOF'
; OPcache configuration
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

# Créer le dossier de logs PHP
mkdir -p /var/log/php
chown www-data:www-data /var/log/php

print_success "PHP configuré pour la production"

################################################################################
# 3. DÉPLOIEMENT DE L'APPLICATION
################################################################################

print_step "3️⃣  Déploiement de l'application"

# Créer le dossier web s'il n'existe pas
mkdir -p "$WEB_ROOT"

# Copier les fichiers de l'application
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$SCRIPT_DIR" != "$WEB_ROOT" ]; then
    print_warning "Copie des fichiers depuis $SCRIPT_DIR vers $WEB_ROOT"

    # Copier tous les fichiers
    cp -r "$SCRIPT_DIR"/* "$WEB_ROOT/"

    # Ne pas copier les fichiers Git et autres
    rm -rf "$WEB_ROOT/.git"
    rm -f "$WEB_ROOT/deploy_interskies.sh"
    rm -f "$WEB_ROOT/DEPLOYMENT_DEBIAN.md"
fi

# Créer les dossiers nécessaires
mkdir -p "$WEB_ROOT/database"
mkdir -p "$WEB_ROOT/photos"
mkdir -p "$WEB_ROOT/data"

# Configurer les permissions
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT/database"
chmod -R 775 "$WEB_ROOT/photos"
chmod -R 775 "$WEB_ROOT/data"

print_success "Application déployée dans $WEB_ROOT"

################################################################################
# 4. INITIALISATION BASE DE DONNÉES
################################################################################

print_step "4️⃣  Initialisation de la base de données"

# La base sera créée automatiquement lors du premier accès
# Mais on peut l'initialiser manuellement si le script de migration existe

if [ -f "$WEB_ROOT/migrate_to_sqlite.php" ]; then
    print_warning "Script de migration détecté"

    # Vérifier s'il y a des données JSON à migrer
    if [ -f "$WEB_ROOT/data/photos.json" ] && [ -s "$WEB_ROOT/data/photos.json" ]; then
        read -p "Migrer les données JSON existantes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo -u www-data php "$WEB_ROOT/migrate_to_sqlite.php"
            print_success "Données migrées vers SQLite"
        fi
    fi

    # Supprimer le script de migration après utilisation
    rm -f "$WEB_ROOT/migrate_to_sqlite.php"
    print_success "Script de migration supprimé (sécurité)"
fi

# Vérifier que la base de données est créée
if [ -f "$WEB_ROOT/database/interskies.db" ]; then
    chmod 600 "$WEB_ROOT/database/interskies.db"
    chown www-data:www-data "$WEB_ROOT/database/interskies.db"
    print_success "Base de données initialisée"
else
    print_warning "La base sera créée au premier accès"
fi

################################################################################
# 5. CONFIGURATION NGINX
################################################################################

print_step "5️⃣  Configuration nginx"

# Détecter le socket PHP-FPM
PHP_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"

if [ ! -S "$PHP_SOCK" ]; then
    print_error "Socket PHP-FPM non trouvé: $PHP_SOCK"
    print_warning "Tentative de démarrage de PHP-FPM..."
    systemctl start php${PHP_VERSION}-fpm
    sleep 2

    if [ ! -S "$PHP_SOCK" ]; then
        print_error "Impossible de démarrer PHP-FPM"
        exit 1
    fi
fi

print_success "Socket PHP-FPM: $PHP_SOCK"

# Copier et adapter la configuration nginx
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

cp "$SCRIPT_DIR/nginx.conf" "$NGINX_CONF"

# Remplacer les placeholders
sed -i "s|interskies.example.com|$DOMAIN|g" "$NGINX_CONF"
sed -i "s|/var/www/interskies|$WEB_ROOT|g" "$NGINX_CONF"
sed -i "s|php8.1-fpm|php${PHP_VERSION}-fpm|g" "$NGINX_CONF"

# Activer le site
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

# Désactiver le site par défaut s'il existe
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

# Tester la configuration
if nginx -t; then
    systemctl reload nginx
    print_success "nginx configuré et rechargé"
else
    print_error "Erreur dans la configuration nginx"
    exit 1
fi

################################################################################
# 6. DÉMARRAGE PHP-FPM
################################################################################

print_step "6️⃣  Démarrage PHP-FPM"

systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
    print_success "PHP-FPM démarré et activé"
else
    print_error "Erreur lors du démarrage de PHP-FPM"
    exit 1
fi

################################################################################
# 7. CONFIGURATION SSL
################################################################################

print_step "7️⃣  Configuration SSL (Let's Encrypt)"

echo "Configuration SSL avec certbot..."
echo "Le domaine doit déjà pointer vers ce serveur"
echo ""
read -p "Configurer SSL maintenant? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Installer certbot si nécessaire
    if ! command -v certbot &> /dev/null; then
        apt-get install -y certbot python3-certbot-nginx
    fi

    # Obtenir le certificat
    certbot --nginx -d $DOMAIN -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        -m $LETSENCRYPT_EMAIL \
        --redirect

    if [ $? -eq 0 ]; then
        print_success "SSL configuré avec succès"

        # Décommenter les lignes HTTPS dans nginx.conf
        sed -i 's/# *server {/server {/g' "$NGINX_CONF"
        sed -i 's/# *listen 443/    listen 443/g' "$NGINX_CONF"
        sed -i 's/# *ssl_/    ssl_/g' "$NGINX_CONF"
        sed -i 's/# *add_header Strict/    add_header Strict/g' "$NGINX_CONF"

        nginx -t && systemctl reload nginx
    else
        print_error "Échec de la configuration SSL"
        print_warning "Vous pouvez le faire manuellement avec:"
        echo "  certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    fi
else
    print_warning "Configuration SSL reportée"
    print_warning "Pour configurer SSL plus tard:"
    echo "  certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

################################################################################
# 8. CONFIGURATION FAIL2BAN
################################################################################

print_step "8️⃣  Configuration Fail2ban pour Interskies"

if command -v fail2ban-client &> /dev/null; then
    # Créer un filtre spécifique pour les tentatives de login
    cat > /etc/fail2ban/filter.d/interskies-auth.conf << 'EOF'
# Fail2Ban filter pour bloquer les tentatives de connexion admin
[Definition]
failregex = ^<HOST> -.*"POST /login\.php HTTP.*" (401|403)
ignoreregex =
EOF

    # Ajouter la jail
    if [ -f /etc/fail2ban/jail.local ]; then
        if ! grep -q "\[interskies-auth\]" /etc/fail2ban/jail.local; then
            cat >> /etc/fail2ban/jail.local << EOF

# Jail Interskies - Protection login admin
[interskies-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/${DOMAIN//./_}_error.log
maxretry = 5
findtime = 600
bantime = 3600
EOF
            systemctl restart fail2ban
            print_success "Jail Fail2ban Interskies ajoutée"
        fi
    fi
else
    print_warning "Fail2ban non installé. Installez-le pour plus de sécurité"
fi

################################################################################
# 9. SÉCURITÉ SUPPLÉMENTAIRE
################################################################################

print_step "9️⃣  Sécurité supplémentaire"

# Supprimer les fichiers sensibles
rm -f "$WEB_ROOT/create_test_photos.php"
rm -f "$WEB_ROOT/.env.example"

print_success "Fichiers sensibles supprimés"

################################################################################
# 10. CHANGEMENT MOT DE PASSE ADMIN
################################################################################

print_step "🔐 Changement du mot de passe administrateur"

print_warning "⚠️  IMPORTANT: Le mot de passe par défaut est 'admin123'"
echo ""
read -p "Voulez-vous changer le mot de passe maintenant? (RECOMMANDÉ) (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Générer un mot de passe aléatoire sécurisé
    NEW_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)

    # Créer un script temporaire
    cat > /tmp/change_admin_pass.php << EOF
<?php
require_once '$WEB_ROOT/auth.php';
if (changePassword('admin', '$NEW_PASSWORD')) {
    echo "✓ Mot de passe changé\n";
} else {
    echo "✗ Erreur\n";
}
?>
EOF

    # Exécuter
    sudo -u www-data php /tmp/change_admin_pass.php

    # Supprimer le script
    rm /tmp/change_admin_pass.php

    echo ""
    print_success "Mot de passe admin changé!"
    print_warning "NOTEZ CE MOT DE PASSE:"
    echo ""
    echo "  ================================================"
    echo "  Utilisateur: admin"
    echo "  Mot de passe: $NEW_PASSWORD"
    echo "  ================================================"
    echo ""
    print_warning "⚠️  Sauvegardez ce mot de passe dans un endroit sûr!"
    echo ""
    read -p "Appuyez sur Entrée une fois que vous avez noté le mot de passe..."
else
    print_warning "⚠️  N'oubliez pas de changer le mot de passe!"
    echo "  Identifiants par défaut:"
    echo "    Utilisateur: admin"
    echo "    Mot de passe: admin123"
fi

################################################################################
# 11. SCRIPT DE SAUVEGARDE
################################################################################

print_step "💾 Configuration du script de sauvegarde"

BACKUP_SCRIPT="/root/scripts/backup_interskies.sh"
mkdir -p /root/scripts

cat > "$BACKUP_SCRIPT" << EOF
#!/bin/bash

# Script de sauvegarde Interskies
BACKUP_DIR="/root/backups/interskies"
DATE=\$(date +%Y%m%d_%H%M%S)
SITE_DIR="$WEB_ROOT"

mkdir -p \$BACKUP_DIR

# Sauvegarder la base de données
if [ -f \$SITE_DIR/database/interskies.db ]; then
    cp \$SITE_DIR/database/interskies.db \$BACKUP_DIR/interskies_\$DATE.db
fi

# Sauvegarder les photos
tar -czf \$BACKUP_DIR/photos_\$DATE.tar.gz -C \$SITE_DIR photos/

# Garder les 30 dernières sauvegardes
find \$BACKUP_DIR -name "interskies_*.db" -mtime +30 -delete
find \$BACKUP_DIR -name "photos_*.tar.gz" -mtime +30 -delete

echo "Sauvegarde Interskies effectuée: \$DATE"
EOF

chmod +x "$BACKUP_SCRIPT"

# Ajouter au cron (tous les jours à 2h)
if ! crontab -l 2>/dev/null | grep -q "backup_interskies.sh"; then
    (crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT") | crontab -
    print_success "Sauvegarde automatique configurée (tous les jours à 2h)"
else
    print_warning "Tâche de sauvegarde déjà configurée"
fi

################################################################################
# FIN
################################################################################

print_step "✅ DÉPLOIEMENT TERMINÉ !"

echo ""
echo "======================================================"
echo "         INTERSKIES - DÉPLOIEMENT RÉUSSI"
echo "======================================================"
echo ""
echo "🌐 URL: https://$DOMAIN"
echo "   Galerie publique: https://$DOMAIN"
echo "   Administration: https://$DOMAIN/admin.php"
echo "   Login: https://$DOMAIN/login.php"
echo ""
echo "📁 Dossiers:"
echo "   Application: $WEB_ROOT"
echo "   Photos: $WEB_ROOT/photos"
echo "   Base de données: $WEB_ROOT/database/interskies.db"
echo ""
echo "🔐 Compte administrateur:"
echo "   Utilisateur: admin"
if [[ ${NEW_PASSWORD:-} ]]; then
    echo "   Mot de passe: $NEW_PASSWORD"
else
    echo "   Mot de passe: admin123 (⚠️ À CHANGER!)"
fi
echo ""
echo "📸 Ajouter des photos:"
echo "   1. Copiez vos photos dans: $WEB_ROOT/photos/"
echo "   2. Elles apparaîtront automatiquement"
echo "   Exemple:"
echo "     scp mes-photos/*.jpg root@$DOMAIN:$WEB_ROOT/photos/"
echo "     sudo chown www-data:www-data $WEB_ROOT/photos/*.jpg"
echo ""
echo "🛡️  Sécurité:"
echo "   - SSL: Activé"
echo "   - Fail2ban: Actif"
echo "   - PHP sécurisé"
echo "   - Sessions sécurisées (30 min timeout)"
echo ""
echo "💾 Sauvegarde:"
echo "   - Automatique: tous les jours à 2h"
echo "   - Dossier: /root/backups/interskies/"
echo "   - Manuel: $BACKUP_SCRIPT"
echo ""
echo "📊 Commandes utiles:"
echo "   - Logs nginx: tail -f /var/log/nginx/${DOMAIN//./_}_access.log"
echo "   - Logs PHP: tail -f /var/log/php/error.log"
echo "   - Status PHP-FPM: systemctl status php${PHP_VERSION}-fpm"
echo "   - Base SQLite: sqlite3 $WEB_ROOT/database/interskies.db"
echo "   - Fail2ban status: fail2ban-client status interskies-auth"
echo ""
echo "📚 Documentation complète:"
echo "   Voir DEPLOYMENT_DEBIAN.md pour plus d'informations"
echo ""
echo "======================================================"
echo ""

print_success "Interskies est prêt à l'emploi! 🎉"

exit 0
