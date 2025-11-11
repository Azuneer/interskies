<?php
session_start();
require_once __DIR__ . '/config/database.php';

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

// Récupérer les paramètres de filtrage et tri
$filterSize = $_GET['size'] ?? 'all';
$filterFormat = $_GET['format'] ?? 'all';
$sortBy = $_GET['sort'] ?? 'recent';

// Construire la requête SQL avec filtres
$query = "SELECT p.*, COUNT(DISTINCT c.id) as comment_count, COUNT(DISTINCT l.id) as like_count
          FROM photos p
          LEFT JOIN comments c ON p.id = c.photo_id
          LEFT JOIN likes l ON p.id = l.photo_id
          WHERE 1=1";

$params = [];

// Filtrer par taille
if ($filterSize !== 'all') {
    if ($filterSize === 'large') {
        $query .= " AND (p.width * p.height) > 2000000";
    } elseif ($filterSize === 'medium') {
        $query .= " AND (p.width * p.height) >= 500000 AND (p.width * p.height) <= 2000000";
    } elseif ($filterSize === 'small') {
        $query .= " AND (p.width * p.height) < 500000";
    }
}

// Filtrer par format
if ($filterFormat !== 'all') {
    if ($filterFormat === 'landscape') {
        $query .= " AND p.width > p.height";
    } elseif ($filterFormat === 'portrait') {
        $query .= " AND p.height > p.width";
    } elseif ($filterFormat === 'square') {
        $query .= " AND ABS(p.width - p.height) < 100";
    }
}

$query .= " GROUP BY p.id";

// Ajouter le tri
switch ($sortBy) {
    case 'recent':
        $query .= " ORDER BY p.created_at DESC";
        break;
    case 'oldest':
        $query .= " ORDER BY p.created_at ASC";
        break;
    case 'likes_desc':
        $query .= " ORDER BY like_count DESC, p.created_at DESC";
        break;
    case 'likes_asc':
        $query .= " ORDER BY like_count ASC, p.created_at DESC";
        break;
    case 'size_desc':
        $query .= " ORDER BY p.size DESC";
        break;
    case 'size_asc':
        $query .= " ORDER BY p.size ASC";
        break;
    case 'name_asc':
        $query .= " ORDER BY p.filename ASC";
        break;
    case 'name_desc':
        $query .= " ORDER BY p.filename DESC";
        break;
    default:
        $query .= " ORDER BY p.created_at DESC";
}

$stmt = $db->prepare($query);
$stmt->execute($params);
$filteredPhotos = $stmt->fetchAll();

// Calculer les statistiques
$totalPhotos = count($filteredPhotos);
$totalSize = array_sum(array_column($filteredPhotos, 'size'));
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Interskies - Galerie de Photos du Ciel</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="icon" type="assets/img" href="assets/img/favicon.png">
    <link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
</head>
<body>
    <div class="container">
        <!-- Sidebar -->
        <aside class="sidebar">
            <h1 class="title">INTERSKIES</h1>

            <div class="stats">
                <div class="stat-item">
                    <span class="stat-label">Photos</span>
                    <span class="stat-value"><?= $totalPhotos ?></span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Taille totale</span>
                    <span class="stat-value"><?= number_format($totalSize / 1024 / 1024, 2) ?> MB</span>
                </div>
            </div>

            <div class="filters">
                <h2>Filtres</h2>

                <form method="GET" id="filter-form">
                    <div class="filter-group">
                        <label for="size">Taille</label>
                        <select name="size" id="size" onchange="this.form.submit()">
                            <option value="all" <?= $filterSize === 'all' ? 'selected' : '' ?>>Toutes</option>
                            <option value="large" <?= $filterSize === 'large' ? 'selected' : '' ?>>Grande (&gt;2MP)</option>
                            <option value="medium" <?= $filterSize === 'medium' ? 'selected' : '' ?>>Moyenne (0.5-2MP)</option>
                            <option value="small" <?= $filterSize === 'small' ? 'selected' : '' ?>>Petite (&lt;0.5MP)</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label for="format">Format</label>
                        <select name="format" id="format" onchange="this.form.submit()">
                            <option value="all" <?= $filterFormat === 'all' ? 'selected' : '' ?>>Tous</option>
                            <option value="landscape" <?= $filterFormat === 'landscape' ? 'selected' : '' ?>>Paysage</option>
                            <option value="portrait" <?= $filterFormat === 'portrait' ? 'selected' : '' ?>>Portrait</option>
                            <option value="square" <?= $filterFormat === 'square' ? 'selected' : '' ?>>Carré</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label for="sort">Trier par</label>
                        <select name="sort" id="sort" onchange="this.form.submit()">
                            <option value="recent" <?= $sortBy === 'recent' ? 'selected' : '' ?>>Plus récent</option>
                            <option value="oldest" <?= $sortBy === 'oldest' ? 'selected' : '' ?>>Plus ancien</option>
                            <option value="likes_desc" <?= $sortBy === 'likes_desc' ? 'selected' : '' ?>>Plus aimés (♥↓)</option>
                            <option value="likes_asc" <?= $sortBy === 'likes_asc' ? 'selected' : '' ?>>Moins aimés (♥↑)</option>
                            <option value="size_desc" <?= $sortBy === 'size_desc' ? 'selected' : '' ?>>Taille (↓)</option>
                            <option value="size_asc" <?= $sortBy === 'size_asc' ? 'selected' : '' ?>>Taille (↑)</option>
                            <option value="name_asc" <?= $sortBy === 'name_asc' ? 'selected' : '' ?>>Nom (A-Z)</option>
                            <option value="name_desc" <?= $sortBy === 'name_desc' ? 'selected' : '' ?>>Nom (Z-A)</option>
                        </select>
                    </div>

                    <?php if ($filterSize !== 'all' || $filterFormat !== 'all'): ?>
                        <button type="button" class="btn-reset" onclick="window.location.href='index.php'">Réinitialiser</button>
                    <?php endif; ?>
                </form>
            </div>

            <div class="admin-panel">
                <h2>Administration</h2>
                <a href="admin.php" class="admin-link">Page Admin</a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="main-content">
            <div class="gallery">
                <?php foreach ($filteredPhotos as $photo): ?>
                    <div class="photo-item" data-id="<?= $photo['id'] ?>" data-filename="<?= htmlspecialchars($photo['filename']) ?>">
                        <img src="photos/<?= htmlspecialchars($photo['filename']) ?>"
                             alt="<?= htmlspecialchars($photo['title'] ?? $photo['filename']) ?>"
                             loading="lazy">
                        <div class="photo-stats">
                            <?php if ($photo['like_count'] > 0): ?>
                                <div class="photo-like-count" data-photo-id="<?= $photo['id'] ?>">
                                    <span class="like-icon">🤍</span> <span class="like-number"><?= $photo['like_count'] ?></span>
                                </div>
                            <?php else: ?>
                                <div class="photo-like-count" data-photo-id="<?= $photo['id'] ?>" style="display: none;">
                                    <span class="like-icon">🤍</span> <span class="like-number">0</span>
                                </div>
                            <?php endif; ?>
                            <?php if ($photo['comment_count'] > 0): ?>
                                <div class="photo-comment-count">
                                    💬 <?= $photo['comment_count'] ?>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </main>
    </div>

    <!-- Modal pour gérer les commentaires -->
    <div id="comments-modal" class="modal">
        <div class="modal-content-split">
            <span class="modal-close">&times;</span>

            <!-- Photo section (left) -->
            <div class="modal-photo-section">
                <img id="modal-photo-img" src="" alt="">
                <div class="modal-photo-info">
                    <span id="modal-photo-filename"></span>
                </div>
            </div>

            <!-- Comments section (right) -->
            <div class="modal-comments-section">
                <h2 id="modal-photo-title">Commentaires</h2>

                <!-- Bouton Like -->
                <div class="modal-like-section">
                    <button id="modal-like-btn" class="like-button" onclick="toggleLike()">
                        <span class="like-icon">🤍</span>
                        <span id="modal-like-count">0</span>
                    </button>
                </div>

                <div id="comments-list"></div>

                <!-- Bouton pour ouvrir le formulaire -->
                <button id="show-comment-form-btn" class="show-comment-form-btn" onclick="showCommentForm()">
                    ✦ Ajouter un commentaire
                </button>

                <!-- Formulaire de commentaire (caché par défaut) -->
                <div class="comment-form" id="comment-form" style="display: none;">
                    <h3>Ajouter un commentaire</h3>
                    <textarea id="comment-content" placeholder="Votre commentaire..." rows="3"></textarea>
                    <input type="text" id="comment-author" placeholder="Votre nom (optionnel)">
                    <div class="comment-form-actions">
                        <button onclick="addComment()" class="btn-submit">Ajouter</button>
                        <button onclick="hideCommentForm()" class="btn-cancel">Annuler</button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="assets/js/script.js"></script>
</body>
</html>
