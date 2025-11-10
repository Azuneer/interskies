#!/bin/bash

################################################################################
# Script de vérification de l'emplacement du site
################################################################################

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

echo "============================================="
echo "  Détection de l'emplacement du site"
echo "============================================="
echo ""

# Méthode 1: Via nginx
print_info "Méthode 1: Configuration nginx"
if [ -d "/etc/nginx/sites-enabled" ]; then
    for site in /etc/nginx/sites-enabled/*; do
        if [ -f "$site" ] && [ "$(basename $site)" != "default" ]; then
            echo "  Fichier: $site"
            ROOT=$(grep -E "^\s*root\s+" "$site" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$ROOT" ]; then
                echo "  → Root détecté: $ROOT"

                # Vérifier si les fichiers existent
                if [ -f "$ROOT/upload.php" ]; then
                    echo "  ✓ upload.php trouvé"
                else
                    echo "  ✗ upload.php MANQUANT"
                fi

                if [ -f "$ROOT/assets/js/photo-upload.js" ]; then
                    echo "  ✓ photo-upload.js trouvé"
                else
                    echo "  ✗ photo-upload.js MANQUANT"
                fi
            fi
        fi
    done
fi
echo ""

# Méthode 2: Chercher tous les répertoires interskies
print_info "Méthode 2: Recherche de tous les dossiers 'interskies'"
find /var/www /home /srv /opt -maxdepth 3 -type d -name "*interskies*" 2>/dev/null | while read dir; do
    echo "  → $dir"
    if [ -f "$dir/index.php" ]; then
        echo "     (contient index.php)"
    fi
    if [ -f "$dir/upload.php" ]; then
        echo "     ✓ upload.php présent"
    fi
    if [ -f "$dir/assets/js/photo-upload.js" ]; then
        echo "     ✓ photo-upload.js présent"
    fi
done
echo ""

# Méthode 3: Processus PHP-FPM
print_info "Méthode 3: Processus PHP-FPM actifs"
ps aux | grep "[p]hp-fpm" | grep -v "master" | head -3
echo ""

# Méthode 4: Derniers fichiers modifiés dans /var/www
print_info "Méthode 4: Fichiers récemment modifiés dans /var/www"
find /var/www -name "*.php" -type f -mtime -1 2>/dev/null | head -10
echo ""

echo "============================================="
echo "Quel est le répertoire root de ton site ?"
echo "============================================="
