#!/bin/bash

################################################################################
# Script de changement de mot de passe administrateur (version automatique)
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

echo "=========================================="
echo "  Changement du mot de passe admin"
echo "=========================================="
echo ""

# Vérifier que le script est dans le bon répertoire
if [ ! -f "config/database.php" ]; then
    print_error "Ce script doit être exécuté depuis le répertoire du site"
    exit 1
fi

# Paramètres
USERNAME="${1:-admin}"
NEW_PASSWORD="${2}"

# Si le mot de passe n'est pas fourni, demander
if [ -z "$NEW_PASSWORD" ]; then
    echo "Nom d'utilisateur: $USERNAME"
    echo ""
    echo -n "Entrez le nouveau mot de passe: "
    read -s NEW_PASSWORD
    echo ""

    if [ ${#NEW_PASSWORD} -lt 6 ]; then
        print_error "Le mot de passe doit contenir au moins 6 caractères"
        exit 1
    fi

    echo -n "Confirmez le mot de passe: "
    read -s PASSWORD_CONFIRM
    echo ""

    if [ "$NEW_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        print_error "Les mots de passe ne correspondent pas"
        exit 1
    fi
fi

print_warning "Changement du mot de passe pour: $USERNAME"

# Créer un script PHP temporaire
TMP_SCRIPT="/tmp/change_pwd_$$.php"

cat > "$TMP_SCRIPT" << 'EOFPHP'
<?php
require_once __DIR__ . '/config/database.php';

$username = $argv[1];
$password = $argv[2];

try {
    $db = getDB();

    // Vérifier que l'utilisateur existe
    $stmt = $db->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user) {
        echo "ERROR: Utilisateur non trouvé\n";
        exit(1);
    }

    // Changer le mot de passe
    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $db->prepare("UPDATE users SET password_hash = ? WHERE username = ?");

    if ($stmt->execute([$passwordHash, $username])) {
        echo "SUCCESS\n";
    } else {
        echo "ERROR: Échec de la mise à jour\n";
        exit(1);
    }
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
EOFPHP

# Exécuter le script PHP
cd "$(dirname "$0")"
RESULT=$(php "$TMP_SCRIPT" "$USERNAME" "$NEW_PASSWORD" 2>&1)

# Supprimer le script temporaire
rm -f "$TMP_SCRIPT"

# Vérifier le résultat
if echo "$RESULT" | grep -q "SUCCESS"; then
    echo ""
    print_success "Mot de passe changé avec succès !"
    echo ""
    echo "Identifiants de connexion:"
    echo "  • Nom d'utilisateur: $USERNAME"
    echo "  • Mot de passe: $NEW_PASSWORD"
    echo ""
    print_success "Vous pouvez maintenant vous connecter sur /admin.php"
else
    echo ""
    print_error "Erreur lors du changement de mot de passe"
    echo "$RESULT"
    exit 1
fi
