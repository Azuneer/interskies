#!/bin/bash

################################################################################
# Script de correction des permissions pour l'upload de photos
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
echo "  Correction des permissions pour l'upload  "
echo "============================================="
echo ""

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

# Créer le dossier photos s'il n'existe pas
PHOTOS_DIR="$WEB_ROOT/photos"

if [ ! -d "$PHOTOS_DIR" ]; then
    print_warning "Création du dossier photos..."
    mkdir -p "$PHOTOS_DIR"
    print_success "Dossier photos créé"
else
    print_success "Dossier photos existe"
fi

# Créer le dossier database s'il n'existe pas
DATABASE_DIR="$WEB_ROOT/database"

if [ ! -d "$DATABASE_DIR" ]; then
    print_warning "Création du dossier database..."
    mkdir -p "$DATABASE_DIR"
    print_success "Dossier database créé"
else
    print_success "Dossier database existe"
fi

echo ""
print_warning "Application des permissions..."

# Définir www-data comme propriétaire
chown -R www-data:www-data "$WEB_ROOT"
print_success "Propriétaire: www-data:www-data"

# Permissions des dossiers (755 = rwxr-xr-x)
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
print_success "Permissions dossiers: 755"

# Permissions des fichiers PHP (644 = rw-r--r--)
find "$WEB_ROOT" -type f -name "*.php" -exec chmod 644 {} \;
print_success "Permissions PHP: 644"

# Permissions des fichiers CSS/JS (644)
find "$WEB_ROOT" -type f \( -name "*.css" -o -name "*.js" \) -exec chmod 644 {} \;
print_success "Permissions CSS/JS: 644"

# Permissions des images (644)
find "$WEB_ROOT" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" \) -exec chmod 644 {} \;
print_success "Permissions images: 644"

# Permissions spéciales pour le dossier photos (775 = rwxrwxr-x)
chmod 775 "$PHOTOS_DIR"
print_success "Permissions dossier photos: 775 (écriture autorisée)"

# Permissions spéciales pour le dossier database (775)
chmod 775 "$DATABASE_DIR"
print_success "Permissions dossier database: 775"

# Permissions de la base de données (664 = rw-rw-r--)
if [ -f "$DATABASE_DIR/interskies.db" ]; then
    chmod 664 "$DATABASE_DIR/interskies.db"
    print_success "Permissions base de données: 664"
fi

# Vérifier que PHP-FPM tourne bien sous www-data
echo ""
print_warning "Vérification du processus PHP-FPM..."

PHP_USER=$(ps aux | grep php-fpm | grep -v grep | grep -v root | head -1 | awk '{print $1}')

if [ "$PHP_USER" = "www-data" ]; then
    print_success "PHP-FPM tourne sous www-data ✓"
else
    print_warning "PHP-FPM tourne sous: $PHP_USER"
    print_warning "Cela peut causer des problèmes de permissions"
fi

echo ""
print_warning "Test des permissions d'écriture..."

# Test d'écriture dans le dossier photos
TEST_FILE="$PHOTOS_DIR/.write_test"
if sudo -u www-data touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    print_success "Test d'écriture dans photos/ réussi ✓"
else
    print_error "Impossible d'écrire dans photos/"
    print_warning "L'upload de photos ne fonctionnera pas"
fi

# Test d'écriture dans le dossier database
TEST_FILE="$DATABASE_DIR/.write_test"
if sudo -u www-data touch "$TEST_FILE" 2>/dev/null; then
    rm -f "$TEST_FILE"
    print_success "Test d'écriture dans database/ réussi ✓"
else
    print_error "Impossible d'écrire dans database/"
fi

echo ""
echo "============================================="
print_success "Correction des permissions terminée !"
echo "============================================="
echo ""
echo "Résumé des permissions:"
echo "  • Propriétaire: www-data:www-data"
echo "  • Dossiers: 755 (rwxr-xr-x)"
echo "  • Fichiers PHP/CSS/JS: 644 (rw-r--r--)"
echo "  • Dossier photos/: 775 (rwxrwxr-x) ← écriture autorisée"
echo "  • Dossier database/: 775 (rwxrwxr-x)"
echo "  • Base de données: 664 (rw-rw-r--)"
echo ""
print_success "L'upload de photos devrait maintenant fonctionner ! 📷"
