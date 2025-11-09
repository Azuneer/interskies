<?php
// Configuration des données
$dataDir = __DIR__ . '/data';
$photosJsonFile = $dataDir . '/photos.json';
$commentsJsonFile = $dataDir . '/comments.json';

// Créer le dossier data s'il n'existe pas
if (!is_dir($dataDir)) {
    mkdir($dataDir, 0777, true);
}

// Initialiser les fichiers JSON s'ils n'existent pas
if (!file_exists($photosJsonFile)) {
    file_put_contents($photosJsonFile, json_encode([], JSON_PRETTY_PRINT));
}
if (!file_exists($commentsJsonFile)) {
    file_put_contents($commentsJsonFile, json_encode([], JSON_PRETTY_PRINT));
}

// Charger les données
$photos = json_decode(file_get_contents($photosJsonFile), true) ?: [];
$comments = json_decode(file_get_contents($commentsJsonFile), true) ?: [];

// Synchroniser les photos du dossier
$photoDir = __DIR__ . '/photos';
$allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

if (is_dir($photoDir)) {
    $files = scandir($photoDir);
    $existingFilenames = array_column($photos, 'filename');

    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;

        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowedExtensions)) continue;

        if (!in_array($file, $existingFilenames)) {
            // Ajouter la nouvelle photo
            $filePath = $photoDir . '/' . $file;
            $imageInfo = @getimagesize($filePath);
            $fileSize = filesize($filePath);

            $newId = empty($photos) ? 1 : max(array_column($photos, 'id')) + 1;

            $photos[] = [
                'id' => $newId,
                'filename' => $file,
                'title' => null,
                'description' => null,
                'width' => $imageInfo[0] ?? 0,
                'height' => $imageInfo[1] ?? 0,
                'size' => $fileSize,
                'created_at' => date('Y-m-d H:i:s')
            ];
        }
    }

    // Supprimer les photos qui n'existent plus
    $photos = array_filter($photos, function($photo) use ($photoDir) {
        return file_exists($photoDir . '/' . $photo['filename']);
    });
    $photos = array_values($photos); // Réindexer

    // Sauvegarder
    file_put_contents($photosJsonFile, json_encode($photos, JSON_PRETTY_PRINT));
}

// Trier par date de création (plus récent en premier)
usort($photos, function($a, $b) {
    return strcmp($b['created_at'], $a['created_at']);
});

// Ajouter le compteur de commentaires
foreach ($photos as &$photo) {
    $photoComments = array_filter($comments, function($c) use ($photo) {
        return $c['photo_id'] == $photo['id'];
    });
    $photo['comment_count'] = count($photoComments);
    $photo['comments'] = array_values($photoComments);

    // Trier les commentaires par date
    usort($photo['comments'], function($a, $b) {
        return strcmp($b['created_at'], $a['created_at']);
    });
}

// Calculer les statistiques
$totalPhotos = count($photos);
$totalSize = array_sum(array_column($photos, 'size'));
$totalComments = count($comments);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Administration - Interskies</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link href="https://fonts.googleapis.com/css2?family=Courier+Prime:wght@400;700&family=Special+Elite&family=Caveat:wght@700&display=swap" rel="stylesheet">
</head>
<body style="background-color: #fffef9; background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,.02) 2px, rgba(0,0,0,.02) 4px);">
    <div class="admin-container">
        <div class="admin-header">
            <h1>Administration</h1>
            <p>Gestion des photos et commentaires</p>
        </div>

        <div class="admin-nav">
            <a href="index.php">← Retour à la galerie</a>
            <div style="flex: 1;"></div>
            <div style="color: #666; font-size: 13px; padding: 12px 0;">
                <?= $totalPhotos ?> photos • <?= $totalComments ?> commentaires • <?= number_format($totalSize / 1024 / 1024, 2) ?> MB
            </div>
        </div>

        <div class="admin-photo-grid">
            <?php foreach ($photos as $photo): ?>
                <div class="admin-photo-card" data-photo-id="<?= $photo['id'] ?>">
                    <img src="photos/<?= htmlspecialchars($photo['filename']) ?>"
                         alt="<?= htmlspecialchars($photo['title'] ?? $photo['filename']) ?>">

                    <div class="admin-photo-info">
                        <h3><?= htmlspecialchars($photo['filename']) ?></h3>
                        <p>Dimensions: <?= $photo['width'] ?>×<?= $photo['height'] ?>px</p>
                        <p>Taille: <?= number_format($photo['size'] / 1024, 2) ?> KB</p>
                        <p>Ajoutée le: <?= date('d/m/Y à H:i', strtotime($photo['created_at'])) ?></p>
                    </div>

                    <div class="admin-comments-section">
                        <h4>Commentaires (<?= $photo['comment_count'] ?>)</h4>

                        <?php if (empty($photo['comments'])): ?>
                            <p style="color: #999; font-size: 12px; padding: 10px 0;">Aucun commentaire</p>
                        <?php else: ?>
                            <div class="admin-comments-list">
                                <?php foreach ($photo['comments'] as $comment): ?>
                                    <div class="admin-comment-item" data-comment-id="<?= $comment['id'] ?>">
                                        <p><strong>~ <?= htmlspecialchars($comment['author']) ?></strong></p>
                                        <p class="comment-text-<?= $comment['id'] ?>"><?= htmlspecialchars($comment['content']) ?></p>
                                        <small><?= date('d/m/Y à H:i', strtotime($comment['created_at'])) ?></small>
                                        <div class="admin-comment-actions">
                                            <button class="btn-small" onclick="editComment(<?= $comment['id'] ?>, <?= $photo['id'] ?>)">
                                                Modifier
                                            </button>
                                            <button class="btn-small" onclick="deleteComment(<?= $comment['id'] ?>, <?= $photo['id'] ?>)">
                                                Supprimer
                                            </button>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>

                        <div style="margin-top: 15px;">
                            <button class="btn-small" onclick="showAddCommentForm(<?= $photo['id'] ?>)"
                                    style="width: 100%; padding: 10px; background-color: #b8a7d4; color: #fff; border-color: #b8a7d4;">
                                + Ajouter un commentaire
                            </button>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>

    <!-- Modal pour ajouter/modifier un commentaire -->
    <div id="comment-modal" class="modal">
        <div class="modal-content">
            <span class="modal-close" onclick="closeCommentModal()">&times;</span>
            <h2 id="modal-title">Ajouter un commentaire</h2>

            <form id="comment-form" style="margin-top: 20px;">
                <input type="hidden" id="form-photo-id">
                <input type="hidden" id="form-comment-id">

                <div style="margin-bottom: 15px;">
                    <label style="display: block; font-size: 13px; color: #666; margin-bottom: 5px; font-weight: 700;">
                        Auteur
                    </label>
                    <input type="text" id="form-author" placeholder="Votre nom"
                           style="width: 100%; padding: 12px; background-color: #fff; color: #2b2b2b; border: 3px solid #2b2b2b; font-family: 'Courier Prime', monospace; font-size: 13px;">
                </div>

                <div style="margin-bottom: 15px;">
                    <label style="display: block; font-size: 13px; color: #666; margin-bottom: 5px; font-weight: 700;">
                        Commentaire
                    </label>
                    <textarea id="form-content" rows="4" placeholder="Votre commentaire..."
                              style="width: 100%; padding: 12px; background-color: #fff; color: #2b2b2b; border: 3px solid #2b2b2b; font-family: 'Courier Prime', monospace; font-size: 13px; resize: vertical;"></textarea>
                </div>

                <div style="display: flex; gap: 10px;">
                    <button type="button" onclick="submitCommentForm()"
                            style="flex: 1; padding: 12px; background-color: #2b2b2b; color: #fff; border: 3px solid #2b2b2b; font-family: 'Courier Prime', monospace; font-size: 13px; font-weight: 700; cursor: pointer; text-transform: uppercase;">
                        Enregistrer
                    </button>
                    <button type="button" onclick="closeCommentModal()"
                            style="padding: 12px 20px; background-color: #fff; color: #2b2b2b; border: 3px solid #2b2b2b; font-family: 'Courier Prime', monospace; font-size: 13px; font-weight: 700; cursor: pointer; text-transform: uppercase;">
                        Annuler
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script src="assets/js/admin-page.js"></script>
</body>
</html>
