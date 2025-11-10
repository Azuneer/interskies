<?php
/**
 * Endpoint d'upload de photos
 */

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/config/database.php';

// Exiger une authentification
requireLogin();

// Configuration de l'upload
$uploadDir = __DIR__ . '/photos';
$maxFileSize = 10 * 1024 * 1024; // 10 MB
$allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
$allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
];

header('Content-Type: application/json');

// Vérifier que c'est bien une requête POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Méthode non autorisée']);
    exit;
}

// Vérifier qu'un fichier a été uploadé
if (!isset($_FILES['photo']) || $_FILES['photo']['error'] === UPLOAD_ERR_NO_FILE) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Aucun fichier sélectionné']);
    exit;
}

$file = $_FILES['photo'];

// Vérifier les erreurs d'upload
if ($file['error'] !== UPLOAD_ERR_OK) {
    $errorMessages = [
        UPLOAD_ERR_INI_SIZE => 'Le fichier dépasse la limite du serveur',
        UPLOAD_ERR_FORM_SIZE => 'Le fichier dépasse la limite du formulaire',
        UPLOAD_ERR_PARTIAL => 'Le fichier a été partiellement uploadé',
        UPLOAD_ERR_NO_TMP_DIR => 'Dossier temporaire manquant',
        UPLOAD_ERR_CANT_WRITE => 'Échec d\'écriture sur le disque',
        UPLOAD_ERR_EXTENSION => 'Upload bloqué par une extension PHP'
    ];

    $errorMsg = $errorMessages[$file['error']] ?? 'Erreur inconnue lors de l\'upload';
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $errorMsg]);
    exit;
}

// Vérifier la taille du fichier
if ($file['size'] > $maxFileSize) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Fichier trop volumineux (max 10 MB)']);
    exit;
}

// Vérifier le type MIME
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

if (!in_array($mimeType, $allowedMimeTypes)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Type de fichier non autorisé']);
    exit;
}

// Vérifier l'extension
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExtensions)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Extension de fichier non autorisée']);
    exit;
}

// Vérifier que c'est bien une image
$imageInfo = @getimagesize($file['tmp_name']);
if ($imageInfo === false) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Le fichier n\'est pas une image valide']);
    exit;
}

// Créer le dossier photos s'il n'existe pas
if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0755, true)) {
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Impossible de créer le dossier photos']);
        exit;
    }
}

// Générer un nom de fichier unique si le fichier existe déjà
$filename = basename($file['name']);
$filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $filename); // Nettoyer le nom
$targetPath = $uploadDir . '/' . $filename;

// Si le fichier existe, ajouter un suffixe numérique
$counter = 1;
$baseFilename = pathinfo($filename, PATHINFO_FILENAME);
$extension = pathinfo($filename, PATHINFO_EXTENSION);

while (file_exists($targetPath)) {
    $filename = $baseFilename . '_' . $counter . '.' . $extension;
    $targetPath = $uploadDir . '/' . $filename;
    $counter++;
}

// Déplacer le fichier uploadé
if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Échec de l\'enregistrement du fichier']);
    exit;
}

// Ajouter la photo à la base de données
try {
    $db = getDB();

    $stmt = $db->prepare("INSERT INTO photos (filename, width, height, size) VALUES (?, ?, ?, ?)");
    $stmt->execute([
        $filename,
        $imageInfo[0],
        $imageInfo[1],
        filesize($targetPath)
    ]);

    $photoId = $db->lastInsertId();

    // Succès
    echo json_encode([
        'success' => true,
        'message' => 'Photo uploadée avec succès',
        'photo' => [
            'id' => $photoId,
            'filename' => $filename,
            'width' => $imageInfo[0],
            'height' => $imageInfo[1],
            'size' => filesize($targetPath)
        ]
    ]);

} catch (Exception $e) {
    // Si l'ajout en base échoue, supprimer le fichier
    @unlink($targetPath);

    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Erreur lors de l\'enregistrement en base de données']);
}
