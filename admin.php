<?php
// Exiger une authentification
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/config/database.php';

requireLogin();

$db = getDB();

// Synchroniser les photos du dossier avec la base de données
$photoDir = __DIR__ . '/photos';
$allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

if (is_dir($photoDir)) {
    $files = scandir($photoDir);

    // Récupérer les fichiers existants en base
    $stmt = $db->query("SELECT filename FROM photos");
    $existingFilenames = $stmt->fetchAll(PDO::FETCH_COLUMN);

    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;

        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowedExtensions)) continue;

        if (!in_array($file, $existingFilenames)) {
            // Ajouter la nouvelle photo
            $filePath = $photoDir . '/' . $file;
            $imageInfo = @getimagesize($filePath);
            $fileSize = filesize($filePath);

            $stmt = $db->prepare("INSERT INTO photos (filename, width, height, size) VALUES (?, ?, ?, ?)");
            $stmt->execute([
                $file,
                $imageInfo[0] ?? 0,
                $imageInfo[1] ?? 0,
                $fileSize
            ]);
        }
    }

    // Supprimer les photos qui n'existent plus
    $stmt = $db->query("SELECT id, filename FROM photos");
    $photos = $stmt->fetchAll();

    foreach ($photos as $photo) {
        if (!file_exists($photoDir . '/' . $photo['filename'])) {
            $deleteStmt = $db->prepare("DELETE FROM photos WHERE id = ?");
            $deleteStmt->execute([$photo['id']]);
        }
    }
}

// Récupérer toutes les photos avec leurs commentaires
$stmt = $db->query("SELECT p.*, COUNT(c.id) as comment_count
                    FROM photos p
                    LEFT JOIN comments c ON p.id = c.photo_id
                    GROUP BY p.id
                    ORDER BY p.created_at DESC");
$photos = $stmt->fetchAll();

// Pour chaque photo, récupérer ses commentaires
foreach ($photos as &$photo) {
    $stmt = $db->prepare("SELECT * FROM comments WHERE photo_id = ? ORDER BY created_at DESC");
    $stmt->execute([$photo['id']]);
    $photo['comments'] = $stmt->fetchAll();
}
unset($photo);

// Calculer les statistiques
$totalPhotos = count($photos);
$totalSize = array_sum(array_column($photos, 'size'));
$stmt = $db->query("SELECT COUNT(*) FROM comments");
$totalComments = $stmt->fetchColumn();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Administration - Interskies</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="icon" type="image/png" href="/favicon.png">
    <link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
</head>
<body style="background-color: var(--bg-primary); background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, var(--shadow-color) 2px, var(--shadow-color) 4px);">
    <div class="admin-container">
        <div class="admin-header">
            <h1>Administration</h1>
            <p>Gestion des photos et commentaires • Connecté en tant que <strong><?= htmlspecialchars($_SESSION['username']) ?></strong></p>
        </div>

        <div class="admin-nav">
            <a href="index.php">← Retour à la galerie</a>
            <button onclick="showUploadModal()" style="margin-left: 15px; padding: 12px 25px; background-color: var(--accent-purple); color: var(--bg-card); border: 3px solid var(--border-color); text-decoration: none; font-weight: 700; font-size: 13px; text-transform: uppercase; box-shadow: 4px 4px 0 var(--shadow-color); cursor: pointer; font-family: 'Space Mono', monospace;">
                📷 Ajouter des photos
            </button>
            <div style="flex: 1;"></div>
            <div style="color: var(--text-secondary); font-size: 13px; padding: 12px 0;">
                <?= $totalPhotos ?> photos • <?= $totalComments ?> commentaires • <?= number_format($totalSize / 1024 / 1024, 2) ?> MB
            </div>
            <form method="POST" action="auth.php" style="margin: 0;">
                <input type="hidden" name="action" value="logout">
                <button type="submit" style="padding: 12px 25px; background-color: var(--accent-pink); color: var(--text-primary); border: 3px solid var(--border-color); text-decoration: none; font-weight: 700; font-size: 13px; text-transform: uppercase; box-shadow: 4px 4px 0 var(--shadow-color); cursor: pointer; font-family: 'Space Mono', monospace;">
                    Déconnexion
                </button>
            </form>
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
                            <p style="color: var(--text-muted); font-size: 12px; padding: 10px 0;">Aucun commentaire</p>
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
                                    style="width: 100%; padding: 10px; background-color: var(--accent-purple); color: var(--bg-card); border-color: var(--accent-purple);">
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
                    <label style="display: block; font-size: 13px; color: var(--text-secondary); margin-bottom: 5px; font-weight: 700;">
                        Auteur
                    </label>
                    <input type="text" id="form-author" placeholder="Votre nom"
                           style="width: 100%; padding: 12px; background-color: var(--bg-card); color: var(--text-primary); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 13px;">
                </div>

                <div style="margin-bottom: 15px;">
                    <label style="display: block; font-size: 13px; color: var(--text-secondary); margin-bottom: 5px; font-weight: 700;">
                        Commentaire
                    </label>
                    <textarea id="form-content" rows="4" placeholder="Votre commentaire..."
                              style="width: 100%; padding: 12px; background-color: var(--bg-card); color: var(--text-primary); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 13px; resize: vertical;"></textarea>
                </div>

                <div style="display: flex; gap: 10px;">
                    <button type="button" onclick="submitCommentForm()"
                            style="flex: 1; padding: 12px; background-color: var(--border-color); color: var(--bg-card); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 13px; font-weight: 700; cursor: pointer; text-transform: uppercase;">
                        Enregistrer
                    </button>
                    <button type="button" onclick="closeCommentModal()"
                            style="padding: 12px 20px; background-color: var(--bg-card); color: var(--text-primary); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 13px; font-weight: 700; cursor: pointer; text-transform: uppercase;">
                        Annuler
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal pour uploader des photos -->
    <div id="upload-modal" class="modal">
        <div class="modal-content" style="max-width: 700px;">
            <span class="modal-close" onclick="closeUploadModal()">&times;</span>
            <h2>📷 Ajouter des photos</h2>

            <div id="upload-area" style="margin-top: 20px; border: 3px dashed var(--border-color); padding: 40px; text-align: center; background-color: var(--bg-card); cursor: pointer; transition: all 0.3s;">
                <input type="file" id="photo-input" accept="image/jpeg,image/png,image/gif,image/webp" multiple style="display: none;">

                <div id="upload-prompt">
                    <div style="font-size: 48px; margin-bottom: 15px;">📁</div>
                    <p style="font-size: 16px; font-weight: 700; margin-bottom: 10px;">Cliquez ou glissez des photos ici</p>
                    <p style="font-size: 13px; color: var(--text-secondary);">
                        Formats: JPG, PNG, GIF, WEBP • Taille max: 10 MB
                    </p>
                </div>

                <div id="upload-preview" style="display: none; margin-top: 20px;">
                    <div id="preview-images" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 15px; margin-bottom: 20px;"></div>
                    <button type="button" onclick="uploadPhotos()" id="upload-btn"
                            style="padding: 15px 30px; background-color: var(--accent-purple); color: var(--bg-card); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 14px; font-weight: 700; cursor: pointer; text-transform: uppercase; box-shadow: 4px 4px 0 var(--shadow-color);">
                        📤 Uploader (<span id="photo-count">0</span>)
                    </button>
                </div>
            </div>

            <div id="upload-progress" style="display: none; margin-top: 20px;">
                <div style="background-color: var(--bg-card); border: 3px solid var(--border-color); padding: 20px;">
                    <p style="font-weight: 700; margin-bottom: 10px;">Upload en cours...</p>
                    <div style="background-color: var(--bg-secondary); height: 30px; border: 3px solid var(--border-color); position: relative; overflow: hidden;">
                        <div id="progress-bar" style="height: 100%; background-color: var(--accent-purple); width: 0%; transition: width 0.3s;"></div>
                        <div id="progress-text" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); font-weight: 700; font-size: 13px;">0%</div>
                    </div>
                    <p id="upload-status" style="margin-top: 10px; font-size: 13px; color: var(--text-secondary);"></p>
                </div>
            </div>

            <div id="upload-results" style="display: none; margin-top: 20px;">
                <div id="results-content"></div>
                <button type="button" onclick="closeUploadModal(); location.reload();"
                        style="margin-top: 15px; padding: 12px 25px; background-color: var(--border-color); color: var(--bg-card); border: 3px solid var(--border-color); font-family: 'Space Mono', monospace; font-size: 13px; font-weight: 700; cursor: pointer; text-transform: uppercase;">
                    Fermer et actualiser
                </button>
            </div>
        </div>
    </div>

    <script src="assets/js/admin-page.js"></script>
    <script src="assets/js/photo-upload.js"></script>
</body>
</html>
