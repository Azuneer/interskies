#!/bin/bash

################################################################################
# Script de diagnostic pour l'upload de photos
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "============================================="
echo "  Diagnostic de l'upload de photos"
echo "============================================="
echo ""

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

# Détecter le répertoire web
if [ -d "/var/www/interskies" ]; then
    WEB_ROOT="/var/www/interskies"
elif [ -d "/var/www/html" ]; then
    WEB_ROOT="/var/www/html"
else
    print_error "Répertoire web non trouvé"
    exit 1
fi

print_success "Répertoire web: $WEB_ROOT"
echo ""

# 1. Vérifier que les fichiers existent
echo "1. Vérification des fichiers..."
FILES_TO_CHECK=("upload.php" "assets/js/photo-upload.js" "photos")

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -e "$WEB_ROOT/$file" ]; then
        print_success "$file existe"
    else
        print_error "$file manquant"
    fi
done
echo ""

# 2. Vérifier les permissions
echo "2. Vérification des permissions..."

# Dossier photos
if [ -d "$WEB_ROOT/photos" ]; then
    PHOTOS_PERMS=$(stat -c "%a" "$WEB_ROOT/photos")
    PHOTOS_OWNER=$(stat -c "%U:%G" "$WEB_ROOT/photos")

    echo "   photos/ → $PHOTOS_PERMS ($PHOTOS_OWNER)"

    if [ "$PHOTOS_PERMS" = "775" ] || [ "$PHOTOS_PERMS" = "777" ]; then
        print_success "Permissions OK pour écriture"
    else
        print_warning "Permissions insuffisantes (devrait être 775 ou 777)"
    fi

    if [ "$PHOTOS_OWNER" = "www-data:www-data" ]; then
        print_success "Propriétaire OK"
    else
        print_warning "Propriétaire incorrect (devrait être www-data:www-data)"
    fi
else
    print_error "Dossier photos/ n'existe pas"
fi

# upload.php
if [ -f "$WEB_ROOT/upload.php" ]; then
    UPLOAD_PERMS=$(stat -c "%a" "$WEB_ROOT/upload.php")
    UPLOAD_OWNER=$(stat -c "%U:%G" "$WEB_ROOT/upload.php")

    echo "   upload.php → $UPLOAD_PERMS ($UPLOAD_OWNER)"

    if [ "$UPLOAD_PERMS" = "644" ] || [ "$UPLOAD_PERMS" = "755" ]; then
        print_success "Permissions OK"
    else
        print_warning "Permissions inhabituelles"
    fi
fi
echo ""

# 3. Test d'écriture
echo "3. Test d'écriture dans photos/..."
TEST_FILE="$WEB_ROOT/photos/.test_upload_$$"

if sudo -u www-data touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    print_success "www-data peut écrire dans photos/"
else
    print_error "www-data NE PEUT PAS écrire dans photos/"
    print_warning "Solution: Lancez ./fix_upload_permissions.sh"
fi
echo ""

# 4. Configuration PHP
echo "4. Configuration PHP..."
PHP_INI=$(php --ini | grep "Loaded Configuration File" | cut -d: -f2 | xargs)
print_info "Fichier de config: $PHP_INI"

if [ -n "$PHP_INI" ] && [ -f "$PHP_INI" ]; then
    UPLOAD_MAX=$(php -r "echo ini_get('upload_max_filesize');")
    POST_MAX=$(php -r "echo ini_get('post_max_size');")
    FILE_UPLOADS=$(php -r "echo ini_get('file_uploads');")

    echo "   upload_max_filesize: $UPLOAD_MAX"
    echo "   post_max_size: $POST_MAX"
    echo "   file_uploads: $FILE_UPLOADS"

    if [ "$FILE_UPLOADS" = "1" ]; then
        print_success "Upload de fichiers activé"
    else
        print_error "Upload de fichiers DÉSACTIVÉ"
    fi
fi
echo ""

# 5. Vérifier nginx
echo "5. Vérification nginx..."

# Trouver le fichier de config du site
NGINX_CONF=$(find /etc/nginx/sites-enabled/ -type f -o -type l | grep -v default | head -1)

if [ -n "$NGINX_CONF" ]; then
    print_info "Config nginx: $NGINX_CONF"

    # Vérifier client_max_body_size
    if grep -q "client_max_body_size" "$NGINX_CONF"; then
        MAX_SIZE=$(grep "client_max_body_size" "$NGINX_CONF" | head -1)
        echo "   $MAX_SIZE"
        print_success "Limite de taille configurée"
    else
        print_warning "client_max_body_size non configuré (défaut: 1M)"
        print_info "Pour augmenter: ajouter 'client_max_body_size 20M;' dans nginx"
    fi

    # Vérifier si upload.php est bloqué
    if grep -q "upload\.php" "$NGINX_CONF"; then
        print_warning "upload.php mentionné dans la config nginx"
        grep "upload\.php" "$NGINX_CONF" | head -3
    else
        print_success "upload.php non bloqué par nginx"
    fi
else
    print_warning "Configuration nginx non trouvée"
fi
echo ""

# 6. Logs nginx
echo "6. Dernières erreurs nginx (si il y en a)..."
if [ -f "/var/log/nginx/error.log" ]; then
    RECENT_ERRORS=$(tail -20 /var/log/nginx/error.log | grep -i "upload\|photo" || true)
    if [ -n "$RECENT_ERRORS" ]; then
        echo "$RECENT_ERRORS"
    else
        print_success "Pas d'erreurs récentes liées à l'upload"
    fi
else
    print_warning "Log nginx non accessible"
fi
echo ""

# 7. Test curl
echo "7. Test d'accès à upload.php..."
DOMAIN=$(ls /etc/nginx/sites-enabled/ | grep -v default | head -1)

if [ -n "$DOMAIN" ]; then
    echo "   Tentative d'accès à https://$DOMAIN/upload.php"

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/upload.php" 2>/dev/null || echo "FAIL")

    if [ "$RESPONSE" = "405" ]; then
        print_success "upload.php accessible (405 = méthode non autorisée, normal pour GET)"
    elif [ "$RESPONSE" = "403" ]; then
        print_error "upload.php bloqué par nginx (403 Forbidden)"
        print_warning "Vérifiez la configuration nginx"
    elif [ "$RESPONSE" = "404" ]; then
        print_error "upload.php non trouvé (404)"
    elif [ "$RESPONSE" = "200" ]; then
        print_warning "upload.php retourne 200 (inhabituel)"
    else
        print_warning "Réponse: $RESPONSE"
    fi
fi
echo ""

echo "============================================="
echo "  Résumé et recommandations"
echo "============================================="
echo ""

if sudo -u www-data test -w "$WEB_ROOT/photos" 2>/dev/null; then
    print_success "Les permissions semblent correctes"
else
    print_error "PROBLÈME: www-data ne peut pas écrire dans photos/"
    echo ""
    echo "Solution:"
    echo "  sudo ./fix_upload_permissions.sh"
    echo ""
fi

print_info "Pour tester l'upload:"
echo "  1. Ouvrez https://$DOMAIN/admin.php"
echo "  2. Ouvrez la Console développeur (F12 → Console)"
echo "  3. Cliquez sur 'Ajouter des photos' et sélectionnez une image"
echo "  4. Regardez les messages dans la console"
echo ""
print_info "Les logs détaillés s'afficheront dans la console du navigateur"
