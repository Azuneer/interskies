#!/bin/bash

################################################################################
# Script d'activation HTTPS pour Interskies
################################################################################
# Active HTTPS avec les certificats Let's Encrypt existants
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

# Vérification root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

echo "=================================="
echo "Activation HTTPS pour Interskies"
echo "=================================="
echo ""

# Détecter le domaine
DOMAIN=$(ls /etc/nginx/sites-enabled/ | grep -v default | head -1)

if [ -z "$DOMAIN" ]; then
    print_error "Aucun site nginx trouvé"
    exit 1
fi

print_success "Domaine détecté: $DOMAIN"

# Vérifier que les certificats existent
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

if [ ! -f "$CERT_PATH/fullchain.pem" ]; then
    print_error "Certificats SSL non trouvés dans $CERT_PATH"
    print_warning "Exécutez d'abord : sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    exit 1
fi

print_success "Certificats SSL trouvés"

# Détecter la version PHP
PHP_VERSION=$(php -v 2>/dev/null | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)

if [ -z "$PHP_VERSION" ]; then
    print_error "PHP non installé"
    exit 1
fi

print_success "Version PHP: $PHP_VERSION"

# Backup de la configuration actuelle
cp "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-available/$DOMAIN.backup-http"
print_success "Backup créé: $DOMAIN.backup-http"

# Créer la nouvelle configuration avec HTTPS
WEB_ROOT=$(grep "root " /etc/nginx/sites-available/$DOMAIN | head -1 | awk '{print $2}' | sed 's/;//')

print_warning "Création de la configuration HTTPS..."

cat > /etc/nginx/sites-available/$DOMAIN << EOF
# Configuration nginx pour Interskies avec HTTPS
# Généré automatiquement

# Redirection HTTP → HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    # Redirection permanente vers HTTPS
    return 301 https://\$server_name\$request_uri;
}

# Configuration HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $DOMAIN www.$DOMAIN;

    # Certificats SSL
    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    ssl_trusted_certificate $CERT_PATH/chain.pem;

    # Configuration SSL moderne
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (force HTTPS pendant 1 an)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Racine du site
    root $WEB_ROOT;
    index index.php index.html;

    # Charset
    charset utf-8;

    # Logs
    access_log /var/log/nginx/${DOMAIN//./_}_access.log;
    error_log /var/log/nginx/${DOMAIN//./_}_error.log;

    # Taille maximale des uploads
    client_max_body_size 50M;

    # ============================================
    # SÉCURITÉ
    # ============================================

    # Headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:;" always;

    # Interdire l'accès aux fichiers sensibles
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Protéger les dossiers database et data
    location ~ ^/(database|data)/ {
        deny all;
        return 403;
    }

    # Interdire l'accès aux fichiers sensibles
    location ~ /(composer\.(json|lock)|\.env|\.git|migrate_to_sqlite\.php|create_test_photos\.php)$ {
        deny all;
        return 403;
    }

    # Interdire l'accès direct aux fichiers de configuration
    location ~ ^/(config|auth\.php) {
        deny all;
        return 403;
    }

    # Protection contre les injections SQL dans l'URL
    if (\$query_string ~* "(union|select|insert|drop|delete|update|alter|create|replace|truncate|concat|script|javascript|eval|base64)") {
        return 403;
    }

    # Protection contre la traversée de répertoire
    if (\$query_string ~* "\.\./|/\.\.|\\\\\.\.") {
        return 403;
    }
    if (\$request_uri ~* "\.\./|/\.\.|\\\\\.\.") {
        return 403;
    }

    # ============================================
    # CACHE ET PERFORMANCE
    # ============================================

    # Cache pour les ressources statiques
    location ~* \.(jpg|jpeg|png|gif|webp|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.(css|js|woff2?|ttf|eot)$ {
        expires 7d;
        add_header Cache-Control "public";
        access_log off;
    }

    # Compression gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";

    # ============================================
    # PHP-FPM
    # ============================================

    # Traitement des fichiers PHP
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        # Socket PHP-FPM
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;

        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;

        # Timeouts pour les requêtes longues
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;

        # Buffers
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }

    # ============================================
    # ROUTING
    # ============================================

    # Page d'accueil
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # API REST
    location /api/ {
        try_files \$uri \$uri/ /api/comments.php?\$query_string;
    }

    # Interdire l'accès au dossier photos via listage
    location /photos/ {
        autoindex off;
        try_files \$uri =404;
    }
}
EOF

print_success "Configuration HTTPS créée"

# Tester la configuration
if nginx -t 2>&1; then
    print_success "Configuration nginx valide"
else
    print_error "Erreur dans la configuration nginx"
    print_warning "Restauration du backup..."
    cp "/etc/nginx/sites-available/$DOMAIN.backup-http" "/etc/nginx/sites-available/$DOMAIN"
    nginx -t
    exit 1
fi

# Recharger nginx
systemctl reload nginx

print_success "Nginx rechargé"

# Tests
echo ""
echo "=================================="
echo "Tests de connexion"
echo "=================================="
echo ""

# Test HTTP (devrait rediriger)
echo "Test HTTP (port 80):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "301" ]; then
    print_success "Redirection HTTP → HTTPS active (301)"
else
    print_warning "Code HTTP: $HTTP_CODE (301 attendu)"
fi

# Test HTTPS
echo "Test HTTPS (port 443):"
if curl -s -k https://localhost > /dev/null 2>&1; then
    print_success "HTTPS fonctionne"
else
    print_error "HTTPS ne répond pas"
fi

# Vérifier les ports
echo ""
echo "Ports en écoute:"
netstat -tlnp 2>/dev/null | grep nginx || ss -tlnp | grep nginx

echo ""
echo "=================================="
echo "Configuration terminée !"
echo "=================================="
echo ""
echo "Votre site est maintenant accessible en HTTPS:"
echo "  https://$DOMAIN"
echo "  https://www.$DOMAIN"
echo ""
echo "HTTP redirige automatiquement vers HTTPS"
echo ""
echo "Backup de l'ancienne config:"
echo "  /etc/nginx/sites-available/$DOMAIN.backup-http"
echo ""
print_success "HTTPS activé avec succès ! 🔒"
