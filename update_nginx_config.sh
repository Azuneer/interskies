#!/bin/bash

################################################################################
# Script de mise à jour de la configuration nginx - Fix 403 auth.php
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

echo "=========================================="
echo "Mise à jour config nginx - Fix auth.php"
echo "=========================================="
echo ""

# Détecter le domaine
DOMAIN=$(ls /etc/nginx/sites-enabled/ | grep -v default | head -1)

if [ -z "$DOMAIN" ]; then
    print_error "Aucun site nginx trouvé"
    exit 1
fi

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

if [ ! -f "$NGINX_CONF" ]; then
    print_error "Configuration nginx non trouvée: $NGINX_CONF"
    exit 1
fi

print_success "Site trouvé: $DOMAIN"
print_success "Configuration: $NGINX_CONF"
echo ""

# Backup de la config actuelle
BACKUP_FILE="${NGINX_CONF}.backup-$(date +%Y%m%d-%H%M%S)"
cp "$NGINX_CONF" "$BACKUP_FILE"
print_success "Backup créé: $BACKUP_FILE"

# Vérifier si la règle auth.php existe déjà
if grep -q "location = /auth.php" "$NGINX_CONF"; then
    print_warning "La configuration auth.php existe déjà"
    echo ""
    echo "Voulez-vous quand même mettre à jour? (o/N)"
    read -r response
    if [[ ! "$response" =~ ^[Oo]$ ]]; then
        print_warning "Annulé"
        exit 0
    fi
fi

# Mettre à jour la configuration
print_warning "Mise à jour de la configuration..."
echo ""

# Détecter version PHP
PHP_VERSION=$(php -v 2>/dev/null | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)

if [ -z "$PHP_VERSION" ]; then
    print_error "Impossible de détecter la version PHP"
    exit 1
fi

print_success "Version PHP détectée: $PHP_VERSION"

# Remplacer l'ancienne règle par la nouvelle
# On cherche le bloc "location ~ ^/(config|auth\.php)" et on le remplace
if grep -q "location ~ \^/(config|auth" "$NGINX_CONF"; then
    # Créer un fichier temporaire avec la nouvelle configuration
    awk -v php_ver="$PHP_VERSION" '
    /location ~ \^\/\(config\|auth/ {
        # On est dans le bloc à remplacer
        print "    # Interdire l'\''accès direct aux fichiers de configuration"
        print "    location ~ ^/config {"
        print "        deny all;"
        print "        return 403;"
        print "    }"
        print ""
        print "    # auth.php : autoriser POST (login/logout), bloquer GET (accès direct)"
        print "    location = /auth.php {"
        print "        if ($request_method = GET) {"
        print "            return 403;"
        print "        }"
        print "        try_files $uri =404;"
        print "        fastcgi_split_path_info ^(.+\\.php)(/.+)$;"
        print "        fastcgi_pass unix:/var/run/php/php" php_ver "-fpm.sock;"
        print "        fastcgi_index index.php;"
        print "        include fastcgi_params;"
        print "        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;"
        print "        fastcgi_param PATH_INFO $fastcgi_path_info;"
        print "    }"

        # Sauter les lignes du bloc original (jusqu'\''au prochain })
        while (getline > 0) {
            if ($0 ~ /^    \}$/) {
                break
            }
        }
        next
    }
    { print }
    ' "$NGINX_CONF" > "${NGINX_CONF}.tmp"

    mv "${NGINX_CONF}.tmp" "$NGINX_CONF"
    print_success "Configuration mise à jour"
else
    print_error "Bloc de configuration auth.php non trouvé"
    print_warning "La configuration doit être mise à jour manuellement"
    exit 1
fi

echo ""
print_warning "Test de la configuration nginx..."

# Tester la configuration
if nginx -t 2>&1; then
    print_success "Configuration nginx valide"
    echo ""
    print_warning "Rechargement de nginx..."
    systemctl reload nginx
    print_success "nginx rechargé"
else
    print_error "Erreur dans la configuration nginx"
    print_warning "Restauration du backup..."
    cp "$BACKUP_FILE" "$NGINX_CONF"
    print_warning "Backup restauré"
    echo ""
    print_error "La mise à jour a échoué"
    nginx -t
    exit 1
fi

echo ""
echo "=========================================="
print_success "Mise à jour terminée !"
echo "=========================================="
echo ""
echo "La connexion admin devrait maintenant fonctionner:"
echo "  https://$DOMAIN/admin.php"
echo ""
echo "Le backup de l'ancienne config est disponible ici:"
echo "  $BACKUP_FILE"
echo ""
print_success "Le problème 403 sur auth.php est résolu ! ✅"
