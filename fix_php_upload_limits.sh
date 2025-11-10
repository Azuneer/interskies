#!/bin/bash

################################################################################
# Script pour augmenter les limites d'upload PHP
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

echo "============================================="
echo "  Augmentation des limites d'upload PHP"
echo "============================================="
echo ""

# Détecter la version PHP
PHP_VERSION=$(php -v 2>/dev/null | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)

if [ -z "$PHP_VERSION" ]; then
    print_error "Impossible de détecter la version PHP"
    exit 1
fi

print_success "Version PHP détectée: $PHP_VERSION"

# Trouver le fichier php.ini de PHP-FPM
PHP_FPM_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

if [ ! -f "$PHP_FPM_INI" ]; then
    print_error "Fichier php.ini non trouvé: $PHP_FPM_INI"
    exit 1
fi

print_success "Fichier PHP-FPM trouvé: $PHP_FPM_INI"
echo ""

# Afficher les valeurs actuelles
print_warning "Valeurs actuelles:"
echo "  upload_max_filesize: $(grep -E "^upload_max_filesize" "$PHP_FPM_INI" | cut -d= -f2 | xargs || echo "non défini")"
echo "  post_max_size: $(grep -E "^post_max_size" "$PHP_FPM_INI" | cut -d= -f2 | xargs || echo "non défini")"
echo "  max_file_uploads: $(grep -E "^max_file_uploads" "$PHP_FPM_INI" | cut -d= -f2 | xargs || echo "non défini")"
echo ""

# Nouvelles valeurs
NEW_UPLOAD_MAX="20M"
NEW_POST_MAX="25M"
NEW_MAX_FILES="20"

print_warning "Nouvelles valeurs:"
echo "  upload_max_filesize: $NEW_UPLOAD_MAX"
echo "  post_max_size: $NEW_POST_MAX"
echo "  max_file_uploads: $NEW_MAX_FILES"
echo ""

echo "Appliquer ces modifications ? (o/N)"
read -r response
if [[ ! "$response" =~ ^[Oo]$ ]]; then
    print_warning "Annulé"
    exit 0
fi

echo ""
print_warning "Modification du fichier php.ini..."

# Backup du fichier original
cp "$PHP_FPM_INI" "${PHP_FPM_INI}.backup-$(date +%Y%m%d-%H%M%S)"
print_success "Backup créé"

# Modifier upload_max_filesize
if grep -q "^upload_max_filesize" "$PHP_FPM_INI"; then
    sed -i "s/^upload_max_filesize.*/upload_max_filesize = $NEW_UPLOAD_MAX/" "$PHP_FPM_INI"
else
    echo "upload_max_filesize = $NEW_UPLOAD_MAX" >> "$PHP_FPM_INI"
fi
print_success "upload_max_filesize modifié"

# Modifier post_max_size
if grep -q "^post_max_size" "$PHP_FPM_INI"; then
    sed -i "s/^post_max_size.*/post_max_size = $NEW_POST_MAX/" "$PHP_FPM_INI"
else
    echo "post_max_size = $NEW_POST_MAX" >> "$PHP_FPM_INI"
fi
print_success "post_max_size modifié"

# Modifier max_file_uploads
if grep -q "^max_file_uploads" "$PHP_FPM_INI"; then
    sed -i "s/^max_file_uploads.*/max_file_uploads = $NEW_MAX_FILES/" "$PHP_FPM_INI"
else
    echo "max_file_uploads = $NEW_MAX_FILES" >> "$PHP_FPM_INI"
fi
print_success "max_file_uploads modifié"

echo ""
print_warning "Redémarrage de PHP-FPM..."

# Redémarrer PHP-FPM
systemctl restart php${PHP_VERSION}-fpm

if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
    print_success "PHP-FPM redémarré avec succès"
else
    print_error "Erreur lors du redémarrage de PHP-FPM"
    exit 1
fi

echo ""
print_warning "Vérification des nouvelles valeurs..."

# Créer un script PHP temporaire pour vérifier
TMP_CHECK="/tmp/check_php_$$.php"
cat > "$TMP_CHECK" << 'EOFPHP'
<?php
echo "upload_max_filesize: " . ini_get('upload_max_filesize') . "\n";
echo "post_max_size: " . ini_get('post_max_size') . "\n";
echo "max_file_uploads: " . ini_get('max_file_uploads') . "\n";
EOFPHP

# Exécuter via PHP-FPM (avec php-cgi si disponible)
if command -v php-cgi &> /dev/null; then
    echo "Valeurs PHP-FPM:"
    REQUEST_METHOD=GET SCRIPT_FILENAME="$TMP_CHECK" php-cgi -q "$TMP_CHECK" 2>/dev/null || php "$TMP_CHECK"
else
    echo "Valeurs PHP CLI (approximatives):"
    php "$TMP_CHECK"
fi

rm -f "$TMP_CHECK"

echo ""
echo "============================================="
print_success "Limites d'upload augmentées !"
echo "============================================="
echo ""
echo "Vous pouvez maintenant uploader:"
echo "  • Fichiers jusqu'à 20 MB"
echo "  • Jusqu'à 20 fichiers à la fois"
echo ""
print_success "Testez l'upload sur votre site !"
