#!/bin/bash

################################################################################
# Script de correction des permissions - Interskies
################################################################################
# Corrige les problèmes de permissions 403 Forbidden
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

echo "=================================="
echo "Correction permissions Interskies"
echo "=================================="
echo ""

# Détecter le domaine
DOMAIN=$(ls /etc/nginx/sites-enabled/ | grep -v default | head -1)

if [ -z "$DOMAIN" ]; then
    print_error "Aucun site nginx trouvé"
    exit 1
fi

WEB_ROOT="/var/www/$DOMAIN"

if [ ! -d "$WEB_ROOT" ]; then
    print_error "Dossier $WEB_ROOT n'existe pas"
    exit 1
fi

print_success "Site trouvé: $DOMAIN"
print_success "Racine web: $WEB_ROOT"
echo ""

# Diagnostic avant correction
echo "État actuel des permissions:"
echo "----------------------------"
echo "Dossier principal:"
ls -ld "$WEB_ROOT"
echo ""

if [ -f "$WEB_ROOT/admin.php" ]; then
    echo "Fichier admin.php:"
    ls -l "$WEB_ROOT/admin.php"
else
    print_error "admin.php n'existe pas !"
fi
echo ""

if [ -f "$WEB_ROOT/index.php" ]; then
    echo "Fichier index.php:"
    ls -l "$WEB_ROOT/index.php"
else
    print_warning "index.php n'existe pas"
fi
echo ""

# Correction des permissions
print_warning "Application des corrections..."
echo ""

# 1. Propriétaire www-data
echo "1. Changement du propriétaire en www-data..."
chown -R www-data:www-data "$WEB_ROOT"
print_success "Propriétaire changé"

# 2. Permissions des dossiers (755 = rwxr-xr-x)
echo "2. Permissions des dossiers (755)..."
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
print_success "Permissions dossiers appliquées"

# 3. Permissions des fichiers (644 = rw-r--r--)
echo "3. Permissions des fichiers PHP (644)..."
find "$WEB_ROOT" -type f -name "*.php" -exec chmod 644 {} \;
find "$WEB_ROOT" -type f -name "*.html" -exec chmod 644 {} \;
print_success "Permissions fichiers PHP/HTML appliquées"

# 4. Permissions des fichiers statiques
echo "4. Permissions fichiers statiques (644)..."
find "$WEB_ROOT" -type f \( -name "*.css" -o -name "*.js" -o -name "*.jpg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" \) -exec chmod 644 {} \; 2>/dev/null || true
print_success "Permissions fichiers statiques appliquées"

# 5. Permissions spéciales pour database (775 pour le dossier, 600 pour la DB)
if [ -d "$WEB_ROOT/database" ]; then
    echo "5. Permissions spéciales pour database..."
    chmod 775 "$WEB_ROOT/database"
    if [ -f "$WEB_ROOT/database/interskies.db" ]; then
        chmod 600 "$WEB_ROOT/database/interskies.db"
        chown www-data:www-data "$WEB_ROOT/database/interskies.db"
        print_success "Base de données sécurisée (600)"
    fi
fi

# 6. Permissions photos (775 pour permettre l'upload)
if [ -d "$WEB_ROOT/photos" ]; then
    echo "6. Permissions dossier photos..."
    chmod 775 "$WEB_ROOT/photos"
    find "$WEB_ROOT/photos" -type f -exec chmod 644 {} \; 2>/dev/null || true
    print_success "Permissions photos appliquées"
fi

# 7. Supprimer les fichiers sensibles s'ils existent
echo "7. Suppression fichiers sensibles..."
rm -f "$WEB_ROOT/migrate_to_sqlite.php"
rm -f "$WEB_ROOT/create_test_photos.php"
rm -f "$WEB_ROOT/diagnostic.sh"
rm -f "$WEB_ROOT/enable_https.sh"
rm -f "$WEB_ROOT/fix_permissions.sh"
rm -rf "$WEB_ROOT/.git"
print_success "Fichiers sensibles supprimés"

echo ""
echo "État après correction:"
echo "---------------------"
echo "Dossier principal:"
ls -ld "$WEB_ROOT"
echo ""

if [ -f "$WEB_ROOT/admin.php" ]; then
    echo "Fichier admin.php:"
    ls -l "$WEB_ROOT/admin.php"
fi
echo ""

if [ -f "$WEB_ROOT/index.php" ]; then
    echo "Fichier index.php:"
    ls -l "$WEB_ROOT/index.php"
fi
echo ""

# Test d'accès
echo "=================================="
echo "Tests d'accès"
echo "=================================="
echo ""

# Test index.php
if curl -s -o /dev/null -w "%{http_code}" http://localhost/index.php | grep -q "200"; then
    print_success "index.php accessible (HTTP 200)"
else
    print_warning "index.php retourne un code différent de 200"
fi

# Test admin.php
ADMIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/admin.php)
if [ "$ADMIN_CODE" = "302" ] || [ "$ADMIN_CODE" = "200" ]; then
    print_success "admin.php accessible (HTTP $ADMIN_CODE)"
    if [ "$ADMIN_CODE" = "302" ]; then
        echo "  → Redirige vers login (normal, authentification requise)"
    fi
else
    print_error "admin.php retourne HTTP $ADMIN_CODE"
fi

# Vérifier les logs nginx
echo ""
echo "Dernières erreurs nginx (si présentes):"
echo "---------------------------------------"
tail -5 /var/log/nginx/interskies_com_error.log 2>/dev/null | grep -v "No such file" || echo "Aucune erreur récente"

echo ""
echo "=================================="
print_success "Corrections appliquées !"
echo "=================================="
echo ""
echo "Résumé des permissions:"
echo "  - Propriétaire: www-data:www-data"
echo "  - Dossiers: 755 (rwxr-xr-x)"
echo "  - Fichiers PHP/HTML: 644 (rw-r--r--)"
echo "  - Base de données: 600 (rw-------)"
echo "  - Dossier photos: 775 (rwxrwxr-x)"
echo ""
echo "Testez maintenant:"
echo "  https://$DOMAIN"
echo "  https://$DOMAIN/admin.php"
echo ""
print_success "Les erreurs 403 devraient être résolues ! ✅"
