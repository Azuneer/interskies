#!/bin/bash

################################################################################
# SCRIPT DE DÉPLOIEMENT FINAL - FONCTIONNALITÉ D'UPLOAD DE PHOTOS
# Ce script configure TOUT ce qui est nécessaire pour l'upload de photos
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BOLD}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

print_header "🚀 DÉPLOIEMENT UPLOAD DE PHOTOS - INTERSKIES"

echo "Ce script va:"
echo "  1. Détecter votre installation"
echo "  2. Copier les fichiers nécessaires"
echo "  3. Configurer les permissions"
echo "  4. Augmenter les limites PHP"
echo "  5. Vérifier que tout fonctionne"
echo ""
echo "Continuer ? (o/N)"
read -r response
if [[ ! "$response" =~ ^[Oo]$ ]]; then
    print_warning "Annulé"
    exit 0
fi

################################################################################
# ÉTAPE 1: DÉTECTION DE L'INSTALLATION
################################################################################

print_header "📍 ÉTAPE 1/5 - Détection de l'installation"

# Trouver le répertoire web via nginx d'abord (plus fiable)
WEB_ROOT=""
for site in /etc/nginx/sites-enabled/*; do
    if [ -f "$site" ] && [ "$(basename $site)" != "default" ]; then
        ROOT=$(grep -E "^\s*root\s+" "$site" | head -1 | awk '{print $2}' | tr -d ';')
        if [ -n "$ROOT" ] && [ -d "$ROOT" ]; then
            WEB_ROOT="$ROOT"
            break
        fi
    fi
done

# Si pas trouvé via nginx, chercher manuellement
if [ -z "$WEB_ROOT" ]; then
    if [ -d "/var/www/interskies.com" ]; then
        WEB_ROOT="/var/www/interskies.com"
    elif [ -d "/var/www/interskies" ]; then
        WEB_ROOT="/var/www/interskies"
    fi
fi

if [ -z "$WEB_ROOT" ]; then
    print_error "Impossible de détecter le répertoire web"
    echo "Entrez le chemin complet (ex: /var/www/interskies.com):"
    read -r WEB_ROOT
    if [ ! -d "$WEB_ROOT" ]; then
        print_error "Le répertoire $WEB_ROOT n'existe pas"
        exit 1
    fi
fi

print_success "Répertoire web: $WEB_ROOT"

# Détecter la version PHP
PHP_VERSION=$(php -v 2>/dev/null | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
if [ -z "$PHP_VERSION" ]; then
    print_error "PHP non installé"
    exit 1
fi
print_success "Version PHP: $PHP_VERSION"

# Vérifier que le répertoire git existe
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/upload.php" ]; then
    print_error "Fichiers source non trouvés dans $SCRIPT_DIR"
    print_warning "Assurez-vous d'être dans le dépôt git du projet"
    exit 1
fi

# Vérifier si on est déjà dans le bon répertoire
if [ "$SCRIPT_DIR" = "$WEB_ROOT" ]; then
    print_warning "Script lancé depuis le répertoire web lui-même"
    print_info "Les fichiers sont déjà au bon endroit, pas besoin de copier"
    SKIP_COPY=1
else
    print_success "Fichiers source: $SCRIPT_DIR → $WEB_ROOT"
    SKIP_COPY=0
fi

################################################################################
# ÉTAPE 2: COPIE DES FICHIERS
################################################################################

print_header "📦 ÉTAPE 2/5 - Copie des fichiers"

# Créer les dossiers nécessaires
mkdir -p "$WEB_ROOT/assets/js"
mkdir -p "$WEB_ROOT/photos"
mkdir -p "$WEB_ROOT/database"

print_success "Dossiers créés"

# Copier les fichiers seulement si nécessaire
if [ $SKIP_COPY -eq 1 ]; then
    print_success "Fichiers déjà en place (pas de copie nécessaire)"

    # Vérifier quand même que les fichiers existent
    if [ -f "$WEB_ROOT/upload.php" ]; then
        print_success "upload.php présent"
    else
        print_error "upload.php MANQUANT"
        exit 1
    fi

    if [ -f "$WEB_ROOT/assets/js/photo-upload.js" ]; then
        print_success "photo-upload.js présent"
    else
        print_error "photo-upload.js MANQUANT"
        exit 1
    fi
else
    # Copier les fichiers
    cp -v "$SCRIPT_DIR/upload.php" "$WEB_ROOT/"
    print_success "upload.php copié"

    cp -v "$SCRIPT_DIR/assets/js/photo-upload.js" "$WEB_ROOT/assets/js/"
    print_success "photo-upload.js copié"

    if [ -f "$SCRIPT_DIR/admin.php" ]; then
        cp -v "$SCRIPT_DIR/admin.php" "$WEB_ROOT/"
        print_success "admin.php copié"
    fi
fi

################################################################################
# ÉTAPE 3: PERMISSIONS
################################################################################

print_header "🔒 ÉTAPE 3/5 - Configuration des permissions"

# Propriétaire www-data
chown -R www-data:www-data "$WEB_ROOT"
print_success "Propriétaire: www-data:www-data"

# Permissions générales
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -name "*.php" -exec chmod 644 {} \;
find "$WEB_ROOT" -type f \( -name "*.css" -o -name "*.js" \) -exec chmod 644 {} \;
print_success "Permissions de base appliquées"

# Permissions spéciales pour photos/
chmod 775 "$WEB_ROOT/photos"
print_success "Dossier photos/ en écriture (775)"

# Permissions database
chmod 775 "$WEB_ROOT/database"
if [ -f "$WEB_ROOT/database/interskies.db" ]; then
    chmod 664 "$WEB_ROOT/database/interskies.db"
fi
print_success "Dossier database/ configuré"

# Test d'écriture
if sudo -u www-data touch "$WEB_ROOT/photos/.test_$$" 2>/dev/null; then
    rm -f "$WEB_ROOT/photos/.test_$$"
    print_success "Test d'écriture: OK ✓"
else
    print_error "PROBLÈME: www-data ne peut pas écrire dans photos/"
    exit 1
fi

################################################################################
# ÉTAPE 4: CONFIGURATION PHP
################################################################################

print_header "⚙️  ÉTAPE 4/5 - Configuration PHP"

PHP_FPM_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

if [ ! -f "$PHP_FPM_INI" ]; then
    print_error "php.ini non trouvé: $PHP_FPM_INI"
    exit 1
fi

print_info "Fichier: $PHP_FPM_INI"

# Valeurs actuelles
CURRENT_UPLOAD=$(grep -E "^upload_max_filesize" "$PHP_FPM_INI" | cut -d= -f2 | xargs || echo "non défini")
CURRENT_POST=$(grep -E "^post_max_size" "$PHP_FPM_INI" | cut -d= -f2 | xargs || echo "non défini")

echo "Valeurs actuelles:"
echo "  upload_max_filesize: $CURRENT_UPLOAD"
echo "  post_max_size: $CURRENT_POST"

# Vérifier si les valeurs sont suffisantes
NEED_UPDATE=0
if [[ "$CURRENT_UPLOAD" == "2M" ]] || [[ "$CURRENT_UPLOAD" == "non défini" ]]; then
    NEED_UPDATE=1
fi

if [ $NEED_UPDATE -eq 1 ]; then
    print_warning "Augmentation des limites PHP..."

    # Backup
    cp "$PHP_FPM_INI" "${PHP_FPM_INI}.backup-$(date +%Y%m%d-%H%M%S)"

    # Modifier
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 20M/' "$PHP_FPM_INI"
    sed -i 's/^post_max_size.*/post_max_size = 25M/' "$PHP_FPM_INI"

    # Si les lignes n'existent pas, les ajouter
    if ! grep -q "^upload_max_filesize" "$PHP_FPM_INI"; then
        echo "upload_max_filesize = 20M" >> "$PHP_FPM_INI"
    fi
    if ! grep -q "^post_max_size" "$PHP_FPM_INI"; then
        echo "post_max_size = 25M" >> "$PHP_FPM_INI"
    fi

    print_success "Limites augmentées: 20M"

    # Redémarrer PHP-FPM
    print_warning "Redémarrage de PHP-FPM..."
    systemctl restart php${PHP_VERSION}-fpm

    if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
        print_success "PHP-FPM redémarré"
    else
        print_error "Erreur lors du redémarrage de PHP-FPM"
        exit 1
    fi
else
    print_success "Limites PHP déjà correctes"
fi

################################################################################
# ÉTAPE 5: VÉRIFICATIONS FINALES
################################################################################

print_header "✅ ÉTAPE 5/5 - Vérifications finales"

# Vérifier les fichiers
CHECKS_OK=1

if [ -f "$WEB_ROOT/upload.php" ]; then
    print_success "upload.php présent"
else
    print_error "upload.php MANQUANT"
    CHECKS_OK=0
fi

if [ -f "$WEB_ROOT/assets/js/photo-upload.js" ]; then
    print_success "photo-upload.js présent"
else
    print_error "photo-upload.js MANQUANT"
    CHECKS_OK=0
fi

if [ -d "$WEB_ROOT/photos" ]; then
    print_success "Dossier photos/ présent"
else
    print_error "Dossier photos/ MANQUANT"
    CHECKS_OK=0
fi

# Vérifier nginx
NGINX_OK=1
DOMAIN=""
for site in /etc/nginx/sites-enabled/*; do
    if [ -f "$site" ] && [ "$(basename $site)" != "default" ]; then
        DOMAIN=$(basename "$site")

        # Vérifier client_max_body_size
        if grep -q "client_max_body_size" "$site"; then
            SIZE=$(grep "client_max_body_size" "$site" | head -1 | awk '{print $2}' | tr -d ';')
            print_success "nginx max size: $SIZE"
        else
            print_warning "client_max_body_size non configuré dans nginx (défaut: 1M)"
            print_info "Ajoutez 'client_max_body_size 50M;' dans $site"
        fi

        # Vérifier que upload.php n'est pas bloqué
        if grep -q "deny.*upload" "$site"; then
            print_error "upload.php semble être bloqué par nginx"
            NGINX_OK=0
        else
            print_success "upload.php non bloqué par nginx"
        fi

        break
    fi
done

################################################################################
# RÉSUMÉ FINAL
################################################################################

print_header "🎉 DÉPLOIEMENT TERMINÉ"

if [ $CHECKS_OK -eq 1 ] && [ $NGINX_OK -eq 1 ]; then
    print_success "Tous les checks sont OK !"
    echo ""
    echo "📸 L'upload de photos est maintenant configuré !"
    echo ""
    echo "Pour tester:"
    echo "  1. Allez sur https://${DOMAIN}/admin.php"
    echo "  2. Connectez-vous"
    echo "  3. Cliquez sur '📷 Ajouter des photos'"
    echo "  4. Sélectionnez des photos (max 20 MB chacune)"
    echo "  5. Cliquez sur 'Uploader'"
    echo ""
    echo "🔍 Debugging:"
    echo "  - Appuyez sur F12 dans le navigateur"
    echo "  - Allez dans l'onglet Console"
    echo "  - Vous verrez les logs détaillés de l'upload"
    echo ""
    print_success "Tout est prêt ! ✨"
else
    print_error "Certaines vérifications ont échoué"
    print_warning "Vérifiez les messages ci-dessus et corrigez les problèmes"
fi

echo ""
echo "Logs importants:"
echo "  - Erreurs nginx: /var/log/nginx/error.log"
echo "  - Erreurs PHP: /var/log/php${PHP_VERSION}-fpm.log"
echo ""
