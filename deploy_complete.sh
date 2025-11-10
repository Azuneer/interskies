#!/bin/bash

################################################################################
# Script de Déploiement Complet - Interskies
################################################################################
# Ce script configure un serveur Debian/Ubuntu depuis zéro et déploie Interskies
#
# Fonctionnalités:
# - Configuration serveur de base (firewall, fail2ban, nginx)
# - Installation PHP (dernière version) + SQLite
# - Déploiement application Interskies
# - SSL/TLS avec Let's Encrypt
# - Sauvegardes automatiques
# - Sécurité production
################################################################################

# Ne pas arrêter le script sur les erreurs mineures
# set -e est trop strict pour un script de déploiement
# On gère les erreurs critiques manuellement

# Couleurs
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

print_step "🚀 Déploiement Complet - Interskies"

echo "Ce script va configurer:"
echo "  - Système de base Debian/Ubuntu"
echo "  - Firewall UFW (SSH port 22 restera ouvert)"
echo "  - nginx + PHP (dernière version) + SQLite"
echo "  - Fail2ban avec protection Interskies"
echo "  - SSL/TLS avec Let's Encrypt"
echo "  - Application Interskies complète"
echo "  - Sauvegardes automatiques"
echo ""
read -p "Voulez-vous continuer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

################################################################################
# COLLECTE DES INFORMATIONS
################################################################################

print_step "📋 Collecte des informations"

read -p "Nom de domaine (ex: interskies.com): " DOMAIN
while [ -z "$DOMAIN" ]; do
    print_error "Le nom de domaine est requis"
    read -p "Nom de domaine: " DOMAIN
done

read -p "Email pour Let's Encrypt et notifications: " LETSENCRYPT_EMAIL
while [ -z "$LETSENCRYPT_EMAIL" ]; do
    print_error "L'email est requis"
    read -p "Email: " LETSENCRYPT_EMAIL
done

read -p "URL du Webhook Discord pour notifications (optionnel): " DISCORD_WEBHOOK

echo ""
print_warning "RÉSUMÉ:"
echo "  - Domaine: $DOMAIN"
echo "  - Email: $LETSENCRYPT_EMAIL"
echo "  - Webhook Discord: ${DISCORD_WEBHOOK:-Non configuré}"
echo "  - Dossier web: /var/www/$DOMAIN"
echo ""
read -p "Confirmer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

WEB_ROOT="/var/www/$DOMAIN"

################################################################################
# 1. MISE À JOUR SYSTÈME
################################################################################

print_step "1️⃣  Mise à jour du système"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y

print_success "Système mis à jour"

################################################################################
# 2. INSTALLATION PAQUETS DE BASE
################################################################################

print_step "2️⃣  Installation des paquets essentiels"

# Installer les paquets de base
apt-get install -y \
    nginx \
    fail2ban \
    ufw \
    curl \
    wget \
    git \
    sudo \
    vim \
    htop \
    unzip \
    gnupg2 \
    ca-certificates \
    lsb-release

print_success "Paquets de base installés"

# Installer certbot (peut nécessiter des dépôts supplémentaires)
print_warning "Installation de certbot..."
apt-get install -y certbot python3-certbot-nginx || {
    print_warning "certbot non disponible dans les dépôts, installation via snap..."
    if command -v snap &> /dev/null; then
        snap install --classic certbot
        ln -sf /snap/bin/certbot /usr/bin/certbot || true
    else
        print_warning "snap non disponible, certbot sera installé plus tard"
    fi
}

print_success "Paquets essentiels installés"

################################################################################
# 3. INSTALLATION PHP (dernière version)
################################################################################

print_step "3️⃣  Installation de PHP"

# Ajouter le dépôt Ondrej Sury pour avoir la dernière version PHP
if [ ! -f /etc/apt/sources.list.d/php.list ]; then
    print_warning "Ajout du dépôt PHP Ondrej Sury..."

    # Ajouter la clé GPG
    curl -sSL https://packages.sury.org/php/README.txt > /dev/null 2>&1 || true
    wget -qO - https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/php-archive-keyring.gpg 2>/dev/null

    # Ajouter le dépôt
    echo "deb [signed-by=/usr/share/keyrings/php-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

    apt-get update
    print_success "Dépôt PHP ajouté"
fi

# Installer PHP (dernière version) et extensions
apt-get install -y \
    php-fpm \
    php-sqlite3 \
    php-cli \
    php-common \
    php-mbstring \
    php-xml \
    php-curl \
    php-gd \
    php-opcache \
    php-zip

# Détecter la version PHP installée
PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
print_success "PHP $PHP_VERSION installé"

################################################################################
# 4. CONFIGURATION PHP
################################################################################

print_step "4️⃣  Configuration PHP pour production"

PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

# Backup
if [ ! -f "${PHP_INI}.backup" ]; then
    cp "$PHP_INI" "${PHP_INI}.backup"
fi

# Configuration sécurité et performance
sed -i 's/^expose_php = On/expose_php = Off/' "$PHP_INI"
sed -i 's/^display_errors = On/display_errors = Off/' "$PHP_INI"
sed -i 's/^;log_errors = On/log_errors = On/' "$PHP_INI"
sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 50M/' "$PHP_INI"
sed -i 's/^;session.cookie_httponly =/session.cookie_httponly = 1/' "$PHP_INI"
sed -i 's/^session.cookie_httponly = .*/session.cookie_httponly = 1/' "$PHP_INI"
sed -i 's/^;session.cookie_secure =/session.cookie_secure = 1/' "$PHP_INI"
sed -i 's/^session.cookie_secure = .*/session.cookie_secure = 1/' "$PHP_INI"

# OPcache
OPCACHE_INI="/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"
cat > "$OPCACHE_INI" << 'EOF'
; OPcache configuration pour production
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.enable_cli=0
EOF

# Logs PHP
mkdir -p /var/log/php
chown www-data:www-data /var/log/php
sed -i "s|^;error_log = .*|error_log = /var/log/php/error.log|" "$PHP_INI"

# Redémarrer PHP-FPM
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

print_success "PHP configuré"

################################################################################
# 5. CONFIGURATION FIREWALL (UFW)
################################################################################

print_step "5️⃣  Configuration du firewall (UFW)"

# Désactiver temporairement
ufw --force disable

# Configuration par défaut
ufw default deny incoming
ufw default allow outgoing

# SSH - PORT 22 RESTE OUVERT
ufw allow 22/tcp comment 'SSH'

# HTTP et HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Activer
ufw --force enable

print_success "Firewall configuré (SSH port 22 ouvert)"

################################################################################
# 6. CONFIGURATION NGINX DE BASE
################################################################################

print_step "6️⃣  Configuration nginx de base"

# Configurer server_tokens dans nginx.conf global
if ! grep -q "server_tokens off;" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    server_tokens off;' /etc/nginx/nginx.conf
fi

# Rate limiting zone
if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;' /etc/nginx/nginx.conf
fi

print_success "nginx configuré"

################################################################################
# 7. DÉPLOIEMENT INTERSKIES
################################################################################

print_step "7️⃣  Déploiement de l'application Interskies"

# Créer le dossier web
mkdir -p "$WEB_ROOT"

# Copier les fichiers de l'application
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$SCRIPT_DIR" != "$WEB_ROOT" ]; then
    print_warning "Copie des fichiers depuis $SCRIPT_DIR vers $WEB_ROOT"

    # Copier tous les fichiers nécessaires
    rsync -av --exclude='.git' \
              --exclude='deploy_*.sh' \
              --exclude='*.md' \
              --exclude='nginx.conf' \
              "$SCRIPT_DIR/" "$WEB_ROOT/"
fi

# Créer les dossiers
mkdir -p "$WEB_ROOT/database"
mkdir -p "$WEB_ROOT/photos"
mkdir -p "$WEB_ROOT/data"

# Permissions
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
chmod -R 775 "$WEB_ROOT/database"
chmod -R 775 "$WEB_ROOT/photos"
chmod -R 775 "$WEB_ROOT/data"

print_success "Application déployée dans $WEB_ROOT"

################################################################################
# 8. INITIALISATION BASE DE DONNÉES
################################################################################

print_step "8️⃣  Initialisation de la base de données"

# Migrer les données JSON si elles existent
if [ -f "$WEB_ROOT/migrate_to_sqlite.php" ]; then
    if [ -f "$WEB_ROOT/data/photos.json" ] && [ -s "$WEB_ROOT/data/photos.json" ]; then
        print_warning "Migration des données JSON..."
        sudo -u www-data php "$WEB_ROOT/migrate_to_sqlite.php" || true
    fi

    # Supprimer le script de migration
    rm -f "$WEB_ROOT/migrate_to_sqlite.php"
fi

# Permissions base de données
if [ -f "$WEB_ROOT/database/interskies.db" ]; then
    chmod 600 "$WEB_ROOT/database/interskies.db"
    chown www-data:www-data "$WEB_ROOT/database/interskies.db"
    print_success "Base de données initialisée"
else
    print_warning "La base sera créée au premier accès"
fi

# Supprimer les fichiers sensibles
rm -f "$WEB_ROOT/create_test_photos.php"

################################################################################
# 9. CONFIGURATION NGINX POUR INTERSKIES
################################################################################

print_step "9️⃣  Configuration nginx pour Interskies"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

# Copier la configuration depuis le dépôt
if [ -f "$SCRIPT_DIR/nginx.conf" ]; then
    cp "$SCRIPT_DIR/nginx.conf" "$NGINX_CONF"
else
    print_error "nginx.conf non trouvé dans $SCRIPT_DIR"
    exit 1
fi

# Remplacer les placeholders
sed -i "s|interskies.example.com|$DOMAIN|g" "$NGINX_CONF"
sed -i "s|/var/www/interskies|$WEB_ROOT|g" "$NGINX_CONF"
sed -i "s|php8.4-fpm|php${PHP_VERSION}-fpm|g" "$NGINX_CONF"

# Créer les logs
touch /var/log/nginx/${DOMAIN//./_}_access.log
touch /var/log/nginx/${DOMAIN//./_}_error.log

# Activer le site
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

# Désactiver le site par défaut
rm -f /etc/nginx/sites-enabled/default

# Tester la configuration
if nginx -t 2>&1; then
    systemctl reload nginx
    print_success "nginx configuré pour $DOMAIN"
else
    print_error "Erreur dans la configuration nginx"
    print_warning "Affichage du test nginx pour debug:"
    nginx -t
    print_error "Vérifiez la configuration nginx et réessayez"
    exit 1
fi

################################################################################
# 10. CONFIGURATION FAIL2BAN
################################################################################

print_step "🔟 Configuration Fail2ban"

# Créer les filtres nginx
cat > /etc/fail2ban/filter.d/nginx-404.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 404
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/nginx-noscript.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/nginx-badbots.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(.*SemrushBot.*|.*AhrefsBot.*|.*MJ12bot.*|.*DotBot.*)"
ignoreregex = .*(googlebot|bingbot|Baiduspider|facebookexternalhit).*
EOF

cat > /etc/fail2ban/filter.d/interskies-auth.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"POST /login\.php HTTP.*" (401|403)
ignoreregex =
EOF

# Configuration jail.local
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = ${LETSENCRYPT_EMAIL}
sendername = Fail2Ban-$DOMAIN
action = %(action_)s

[nginx-404]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 10
findtime = 60
bantime = 3600

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 5
findtime = 300
bantime = 7200

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
findtime = 600
bantime = 86400

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 600
bantime = 7200

[interskies-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/${DOMAIN//./_}_error.log
maxretry = 5
findtime = 600
bantime = 3600
EOF

systemctl restart fail2ban
systemctl enable fail2ban

print_success "Fail2ban configuré avec protection Interskies"

################################################################################
# 11. SCRIPTS DE MAINTENANCE
################################################################################

print_step "1️⃣1️⃣  Scripts de maintenance et sauvegardes"

SCRIPTS_DIR="/root/scripts"
mkdir -p $SCRIPTS_DIR

# Script de mise à jour automatique
cat > $SCRIPTS_DIR/maj_auto.sh << 'EOFSCRIPT'
#!/bin/bash

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-""}"
HOSTNAME=$(hostname)
LOG_FILE="/var/log/system_update_$(date +'%Y-%m-%d').log"

send_success_notification() {
  MESSAGE="✅ Mise à jour automatique réussie sur **$HOSTNAME**"
  JSON_PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Rapport de mise à jour",
    "description": "$MESSAGE",
    "color": 3066993,
    "footer": {"text": "$(date -u --iso-8601=seconds)"}
  }]
}
EOF
)
  [ -n "$WEBHOOK_URL" ] && curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
}

send_failure_notification() {
  ERROR_LOG=$(tail -n 20 "$LOG_FILE")
  MESSAGE="❌ Échec mise à jour sur **$HOSTNAME**"
  JSON_PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "Rapport de mise à jour",
    "description": "$MESSAGE",
    "color": 15158332,
    "fields": [{"name": "Erreur", "value": "\`\`\`$ERROR_LOG\`\`\`"}],
    "footer": {"text": "$(date -u --iso-8601=seconds)"}
  }]
}
EOF
)
  [ -n "$WEBHOOK_URL" ] && curl -H "Content-Type: application/json" -X POST -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
}

echo "--- Début mise à jour : $(date) ---" > "$LOG_FILE"

if apt-get update -y >> "$LOG_FILE" 2>&1 && apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
  echo "--- Succès : $(date) ---" >> "$LOG_FILE"
  send_success_notification
else
  echo "--- Échec : $(date) ---" >> "$LOG_FILE"
  send_failure_notification
fi

exit 0
EOFSCRIPT

chmod +x $SCRIPTS_DIR/maj_auto.sh

# Script de sauvegarde Interskies
cat > $SCRIPTS_DIR/backup_interskies.sh << EOF
#!/bin/bash

BACKUP_DIR="/root/backups/interskies"
DATE=\$(date +%Y%m%d_%H%M%S)
SITE_DIR="$WEB_ROOT"

mkdir -p \$BACKUP_DIR

# Sauvegarder la base
[ -f \$SITE_DIR/database/interskies.db ] && cp \$SITE_DIR/database/interskies.db \$BACKUP_DIR/interskies_\$DATE.db

# Sauvegarder les photos
tar -czf \$BACKUP_DIR/photos_\$DATE.tar.gz -C \$SITE_DIR photos/ 2>/dev/null || true

# Garder 30 derniers jours
find \$BACKUP_DIR -name "interskies_*.db" -mtime +30 -delete
find \$BACKUP_DIR -name "photos_*.tar.gz" -mtime +30 -delete

echo "Sauvegarde Interskies: \$DATE"
EOF

chmod +x $SCRIPTS_DIR/backup_interskies.sh

# Configuration cron
if ! crontab -l 2>/dev/null | grep -q "maj_auto.sh"; then
    CRON_LINE="0 3 */2 * * DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK\" $SCRIPTS_DIR/maj_auto.sh"
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
fi

if ! crontab -l 2>/dev/null | grep -q "backup_interskies.sh"; then
    (crontab -l 2>/dev/null; echo "0 2 * * * $SCRIPTS_DIR/backup_interskies.sh") | crontab -
fi

print_success "Scripts de maintenance configurés"

################################################################################
# 12. CHANGEMENT MOT DE PASSE ADMIN
################################################################################

print_step "1️⃣2️⃣  Configuration mot de passe administrateur"

print_warning "⚠️  IMPORTANT: Génération d'un mot de passe sécurisé"

# Générer un mot de passe aléatoire
NEW_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-20)

# Créer script temporaire
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
sudo -u www-data php /tmp/change_admin_pass.php 2>/dev/null || print_warning "La base sera initialisée au premier accès"

# Supprimer le script
rm -f /tmp/change_admin_pass.php

################################################################################
# 13. CONFIGURATION SSL
################################################################################

print_step "1️⃣3️⃣  Configuration SSL avec Let's Encrypt"

echo "Le certificat SSL nécessite que le domaine pointe vers ce serveur"
echo ""
read -p "Configurer SSL maintenant? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    certbot --nginx -d $DOMAIN -d www.$DOMAIN \
        --non-interactive \
        --agree-tos \
        -m $LETSENCRYPT_EMAIL \
        --redirect || print_warning "Échec SSL. Configurez manuellement avec: certbot --nginx -d $DOMAIN"

    if [ $? -eq 0 ]; then
        print_success "SSL configuré avec succès"
    fi
else
    print_warning "Configuration SSL reportée"
    echo "Pour configurer plus tard: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

################################################################################
# FIN
################################################################################

print_step "✅ DÉPLOIEMENT TERMINÉ !"

echo ""
echo "======================================================"
echo "         INTERSKIES - CONFIGURATION COMPLÈTE"
echo "======================================================"
echo ""
echo "🌐 Site:"
echo "   URL: https://$DOMAIN"
echo "   Galerie: https://$DOMAIN"
echo "   Admin: https://$DOMAIN/admin.php"
echo "   Login: https://$DOMAIN/login.php"
echo ""
echo "🔐 Compte administrateur:"
echo "   Utilisateur: admin"
echo "   Mot de passe: $NEW_PASSWORD"
echo ""
print_warning "⚠️  SAUVEGARDEZ CE MOT DE PASSE MAINTENANT!"
echo ""
echo "📁 Dossiers:"
echo "   Application: $WEB_ROOT"
echo "   Photos: $WEB_ROOT/photos/"
echo "   Base: $WEB_ROOT/database/interskies.db"
echo ""
echo "📸 Ajouter des photos:"
echo "   scp mes-photos/*.jpg root@$DOMAIN:$WEB_ROOT/photos/"
echo "   sudo chown www-data:www-data $WEB_ROOT/photos/*.jpg"
echo ""
echo "🛡️  Sécurité:"
echo "   - Firewall: Actif (SSH port 22 ouvert)"
echo "   - Fail2ban: Actif (6 jails nginx + interskies)"
echo "   - PHP $PHP_VERSION: Configuré avec OPcache"
echo "   - SSL: ${REPLY}"
echo ""
echo "💾 Maintenance:"
echo "   - Sauvegarde auto: Quotidienne à 2h"
echo "   - Update auto: Tous les 2 jours à 3h"
echo "   - Backup manuel: $SCRIPTS_DIR/backup_interskies.sh"
echo ""
echo "📊 Commandes utiles:"
echo "   nginx -t                         # Tester config nginx"
echo "   systemctl status php${PHP_VERSION}-fpm  # Status PHP"
echo "   fail2ban-client status           # Status Fail2ban"
echo "   tail -f /var/log/nginx/${DOMAIN//./_}_access.log"
echo "   sqlite3 $WEB_ROOT/database/interskies.db"
echo ""
echo "======================================================"
echo ""

print_success "Interskies est prêt! 🎉"

exit 0
