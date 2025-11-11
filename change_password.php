#!/usr/bin/env php
<?php
/**
 * Script pour changer le mot de passe administrateur
 * Usage: php change_password.php
 */

// Vérifier qu'on est en CLI
if (php_sapi_name() !== 'cli') {
    die("Ce script doit être exécuté en ligne de commande\n");
}

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/auth.php';

echo "=====================================\n";
echo "  Changement du mot de passe admin  \n";
echo "=====================================\n\n";

// Récupérer la liste des utilisateurs
$db = getDB();
$stmt = $db->query("SELECT id, username FROM users ORDER BY id");
$users = $stmt->fetchAll();

if (empty($users)) {
    echo "❌ Aucun utilisateur trouvé dans la base de données\n";
    exit(1);
}

echo "Utilisateurs disponibles:\n";
foreach ($users as $index => $user) {
    echo "  " . ($index + 1) . ". " . $user['username'] . "\n";
}
echo "\n";

// Demander quel utilisateur modifier
if (count($users) === 1) {
    $selectedUser = $users[0];
    echo "Utilisateur sélectionné: " . $selectedUser['username'] . "\n\n";
} else {
    echo "Sélectionnez un utilisateur (1-" . count($users) . "): ";
    $choice = trim(fgets(STDIN));

    if (!is_numeric($choice) || $choice < 1 || $choice > count($users)) {
        echo "❌ Choix invalide\n";
        exit(1);
    }

    $selectedUser = $users[$choice - 1];
    echo "Utilisateur sélectionné: " . $selectedUser['username'] . "\n\n";
}

// Demander le nouveau mot de passe
echo "Entrez le nouveau mot de passe: ";
$password = trim(fgets(STDIN));

if (strlen($password) < 6) {
    echo "❌ Le mot de passe doit contenir au moins 6 caractères\n";
    exit(1);
}

// Demander confirmation
echo "Confirmez le mot de passe: ";
$passwordConfirm = trim(fgets(STDIN));

if ($password !== $passwordConfirm) {
    echo "❌ Les mots de passe ne correspondent pas\n";
    exit(1);
}

// Changer le mot de passe
if (changePassword($selectedUser['username'], $password)) {
    echo "\n✅ Mot de passe changé avec succès pour l'utilisateur '" . $selectedUser['username'] . "'\n\n";
    echo "Vous pouvez maintenant vous connecter avec:\n";
    echo "  • Nom d'utilisateur: " . $selectedUser['username'] . "\n";
    echo "  • Mot de passe: " . $password . "\n\n";
} else {
    echo "❌ Erreur lors du changement de mot de passe\n";
    exit(1);
}
