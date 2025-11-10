#!/bin/bash

################################################################################
# Script de mise à jour rapide du site
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
echo "  Déploiement des fichiers d'upload"
echo "============================================="
echo ""

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "upload.php" ]; then
    print_error "upload.php non trouvé dans le répertoire courant"
    echo "Assurez-vous d'être dans le dépôt git du projet"
    exit 1
fi

print_success "Fichiers trouvés dans le répertoire courant"
echo ""

# Détecter le répertoire web via nginx
print_info "Détection du répertoire web..."

WEB_ROOT=""
if [ -d "/etc/nginx/sites-enabled" ]; then
    for site in /etc/nginx/sites-enabled/*; do
        if [ -f "$site" ] && [ "$(basename $site)" != "default" ]; then
            ROOT=$(grep -E "^\s*root\s+" "$site" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$ROOT" ] && [ -d "$ROOT" ]; then
                WEB_ROOT="$ROOT"
                SITE_NAME=$(basename "$site")
                break
            fi
        fi
    done
fi

if [ -z "$WEB_ROOT" ]; then
    print_warning "Impossible de détecter automatiquement le répertoire web"
    echo ""
    echo "Entrez le chemin complet du répertoire de votre site:"
    echo "(exemple: /var/www/interskies)"
    read -r WEB_ROOT

    if [ ! -d "$WEB_ROOT" ]; then
        print_error "Le répertoire $WEB_ROOT n'existe pas"
        exit 1
    fi
fi

print_success "Répertoire web détecté: $WEB_ROOT"
echo ""

# Afficher les fichiers à copier
print_info "Fichiers à déployer:"
echo "  - upload.php"
echo "  - assets/js/photo-upload.js"
echo "  - admin.php (mis à jour)"
echo ""

# Demander confirmation
echo "Voulez-vous déployer ces fichiers vers $WEB_ROOT ? (o/N)"
read -r response
if [[ ! "$response" =~ ^[Oo]$ ]]; then
    print_warning "Annulé"
    exit 0
fi

echo ""
print_warning "Déploiement en cours..."

# Créer le dossier assets/js s'il n'existe pas
if [ ! -d "$WEB_ROOT/assets/js" ]; then
    mkdir -p "$WEB_ROOT/assets/js"
    print_success "Dossier assets/js créé"
fi

# Copier les fichiers
cp -v upload.php "$WEB_ROOT/"
print_success "upload.php copié"

cp -v assets/js/photo-upload.js "$WEB_ROOT/assets/js/"
print_success "photo-upload.js copié"

cp -v admin.php "$WEB_ROOT/"
print_success "admin.php mis à jour"

# Fixer les permissions
chown www-data:www-data "$WEB_ROOT/upload.php"
chown www-data:www-data "$WEB_ROOT/assets/js/photo-upload.js"
chown www-data:www-data "$WEB_ROOT/admin.php"
chmod 644 "$WEB_ROOT/upload.php"
chmod 644 "$WEB_ROOT/assets/js/photo-upload.js"
chmod 644 "$WEB_ROOT/admin.php"
print_success "Permissions corrigées"

echo ""
print_success "Déploiement terminé !"
echo ""

# Vérifier que les fichiers sont bien là
print_info "Vérification..."
if [ -f "$WEB_ROOT/upload.php" ]; then
    print_success "upload.php présent"
else
    print_error "upload.php manquant"
fi

if [ -f "$WEB_ROOT/assets/js/photo-upload.js" ]; then
    print_success "photo-upload.js présent"
else
    print_error "photo-upload.js manquant"
fi

echo ""
echo "============================================="
print_success "Les fichiers d'upload sont déployés !"
echo "============================================="
echo ""
echo "Prochaine étape:"
echo "  1. Exécutez: sudo ./fix_upload_permissions.sh"
echo "  2. Testez l'upload sur https://${SITE_NAME:-votre-domaine}/admin.php"
echo "  3. Ouvrez F12 pour voir les logs"
