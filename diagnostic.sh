#!/bin/bash

# Script de diagnostic Interskies
# À exécuter sur le serveur pour voir ce qui ne va pas

echo "================================"
echo "DIAGNOSTIC INTERSKIES"
echo "================================"
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Vérifier nginx
echo "1. Status nginx:"
systemctl status nginx --no-pager | head -3
echo ""

# 2. Vérifier PHP-FPM
echo "2. Status PHP-FPM:"
PHP_VERSION=$(php -v 2>/dev/null | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
if [ -n "$PHP_VERSION" ]; then
    systemctl status php${PHP_VERSION}-fpm --no-pager | head -3
else
    echo -e "${RED}PHP non installé${NC}"
fi
echo ""

# 3. Vérifier les fichiers
echo "3. Contenu de /var/www:"
ls -la /var/www/
echo ""

DOMAIN=$(ls /etc/nginx/sites-enabled/ | grep -v default | head -1)
if [ -n "$DOMAIN" ]; then
    WEB_ROOT="/var/www/$DOMAIN"
    echo "4. Contenu de $WEB_ROOT:"
    ls -la "$WEB_ROOT/" 2>/dev/null || echo -e "${RED}Dossier vide ou inexistant${NC}"
    echo ""

    echo "5. Fichiers PHP présents:"
    find "$WEB_ROOT" -name "*.php" -type f 2>/dev/null | head -10
    echo ""
fi

# 6. Configuration nginx active
echo "6. Sites nginx actifs:"
ls -l /etc/nginx/sites-enabled/
echo ""

# 7. Test nginx
echo "7. Test configuration nginx:"
nginx -t
echo ""

# 8. Logs nginx récents
echo "8. Dernières erreurs nginx:"
tail -5 /var/log/nginx/error.log 2>/dev/null || echo "Pas de logs d'erreur"
echo ""

# 9. Test local
echo "9. Test requête locale:"
curl -I http://localhost 2>/dev/null | head -5
echo ""

# 10. Ports en écoute
echo "10. Ports en écoute:"
netstat -tlnp 2>/dev/null | grep -E '(nginx|php)' || ss -tlnp | grep -E '(nginx|php)'
echo ""

# 11. Permissions
if [ -n "$WEB_ROOT" ] && [ -d "$WEB_ROOT" ]; then
    echo "11. Permissions $WEB_ROOT:"
    ls -ld "$WEB_ROOT"
    echo ""

    echo "12. Propriétaire fichiers:"
    ls -l "$WEB_ROOT" | head -10
fi
echo ""

echo "================================"
echo "FIN DU DIAGNOSTIC"
echo "================================"
