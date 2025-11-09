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

// Récupérer les paramètres de filtrage et tri
$filterSize = $_GET['size'] ?? 'all';
$filterFormat = $_GET['format'] ?? 'all';
$sortBy = $_GET['sort'] ?? 'recent';

// Filtrer les photos
$filteredPhotos = $photos;

if ($filterSize !== 'all') {
    $filteredPhotos = array_filter($filteredPhotos, function($photo) use ($filterSize) {
        $pixels = $photo['width'] * $photo['height'];
        if ($filterSize === 'large') return $pixels > 2000000;
        if ($filterSize === 'medium') return $pixels >= 500000 && $pixels <= 2000000;
        if ($filterSize === 'small') return $pixels < 500000;
        return true;
    });
}

if ($filterFormat !== 'all') {
    $filteredPhotos = array_filter($filteredPhotos, function($photo) use ($filterFormat) {
        if ($filterFormat === 'landscape') return $photo['width'] > $photo['height'];
        if ($filterFormat === 'portrait') return $photo['height'] > $photo['width'];
        if ($filterFormat === 'square') return abs($photo['width'] - $photo['height']) < 100;
        return true;
    });
}

// Trier les photos
usort($filteredPhotos, function($a, $b) use ($sortBy) {
    switch ($sortBy) {
        case 'recent':
            return strcmp($b['created_at'], $a['created_at']);
        case 'oldest':
            return strcmp($a['created_at'], $b['created_at']);
        case 'size_desc':
            return $b['size'] - $a['size'];
        case 'size_asc':
            return $a['size'] - $b['size'];
        case 'name_asc':
            return strcmp($a['filename'], $b['filename']);
        case 'name_desc':
            return strcmp($b['filename'], $a['filename']);
        default:
            return 0;
    }
});

// Ajouter le compteur de commentaires
foreach ($filteredPhotos as &$photo) {
    $photoComments = array_filter($comments, function($c) use ($photo) {
        return $c['photo_id'] == $photo['id'];
    });
    $photo['comment_count'] = count($photoComments);
}

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
                        <?php if ($photo['comment_count'] > 0): ?>
                            <div class="photo-comment-count">
                                💬 <?= $photo['comment_count'] ?>
                            </div>
                        <?php endif; ?>
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

                <div id="comments-list"></div>

                <div class="comment-form">
                    <h3>Ajouter un commentaire</h3>
                    <textarea id="comment-content" placeholder="Votre commentaire..." rows="3"></textarea>
                    <input type="text" id="comment-author" placeholder="Votre nom (optionnel)">
                    <button onclick="addComment()">Ajouter</button>
                </div>
            </div>
        </div>
    </div>

    <script src="assets/js/script.js"></script>
</body>
</html>
