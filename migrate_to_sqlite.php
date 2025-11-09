<?php
/**
 * Script de migration JSON vers SQLite
 * À exécuter une seule fois pour migrer les données existantes
 */

require_once __DIR__ . '/config/database.php';

echo "=== Migration JSON vers SQLite ===\n\n";

$db = getDB();

// Dossiers et fichiers
$dataDir = __DIR__ . '/data';
$photosJsonFile = $dataDir . '/photos.json';
$commentsJsonFile = $dataDir . '/comments.json';

// 1. Migrer les photos
if (file_exists($photosJsonFile)) {
    echo "Migration des photos...\n";

    $photosJson = file_get_contents($photosJsonFile);
    $photos = json_decode($photosJson, true) ?: [];

    $stmt = $db->prepare("INSERT OR REPLACE INTO photos (id, filename, title, description, width, height, size, created_at)
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

    foreach ($photos as $photo) {
        $stmt->execute([
            $photo['id'],
            $photo['filename'],
            $photo['title'],
            $photo['description'],
            $photo['width'],
            $photo['height'],
            $photo['size'],
            $photo['created_at']
        ]);
    }

    echo "✓ " . count($photos) . " photos migrées\n";
} else {
    echo "Aucun fichier photos.json trouvé\n";
}

// 2. Migrer les commentaires
if (file_exists($commentsJsonFile)) {
    echo "Migration des commentaires...\n";

    $commentsJson = file_get_contents($commentsJsonFile);
    $comments = json_decode($commentsJson, true) ?: [];

    $stmt = $db->prepare("INSERT OR REPLACE INTO comments (id, photo_id, content, author, created_at)
                          VALUES (?, ?, ?, ?, ?)");

    foreach ($comments as $comment) {
        $stmt->execute([
            $comment['id'],
            $comment['photo_id'],
            $comment['content'],
            $comment['author'],
            $comment['created_at']
        ]);
    }

    echo "✓ " . count($comments) . " commentaires migrés\n";
} else {
    echo "Aucun fichier comments.json trouvé\n";
}

echo "\n=== Migration terminée ===\n";
echo "Base de données créée : " . DB_PATH . "\n";
echo "Utilisateur admin créé avec mot de passe : admin123\n";
echo "⚠️  IMPORTANT : Changez ce mot de passe après la première connexion!\n";
?>
