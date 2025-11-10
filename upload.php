<?php
/**
 * Endpoint d'upload de photos - Version finale
 */

// Logs de debug
error_log("=== UPLOAD.PHP START ===");
error_log("Method: " . $_SERVER['REQUEST_METHOD']);
error_log("Session ID: " . session_id());

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/config/database.php';

// Exiger une authentification
if (!isLoggedIn()) {
    error_log("ERREUR: User not logged in");
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'Non authentifié - veuillez vous reconnecter']);
    exit;
}

error_log("User authenticated: " . $_SESSION['username']);

// Configuration de l'upload
$uploadDir = __DIR__ . '/photos';
$maxFileSize = 20 * 1024 * 1024; // 20 MB
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
    error_log("ERREUR: Wrong method");
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Méthode non autorisée']);
    exit;
}

// Vérifier qu'un fichier a été uploadé
if (!isset($_FILES['photo']) || $_FILES['photo']['error'] === UPLOAD_ERR_NO_FILE) {
    error_log("ERREUR: No file uploaded");
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Aucun fichier sélectionné']);
    exit;
}

$file = $_FILES['photo'];
error_log("File uploaded: " . $file['name'] . " (" . $file['size'] . " bytes)");

// Vérifier les erreurs d'upload
if ($file['error'] !== UPLOAD_ERR_OK) {
    $errorMessages = [
        UPLOAD_ERR_INI_SIZE => 'Le fichier dépasse la limite du serveur (upload_max_filesize)',
        UPLOAD_ERR_FORM_SIZE => 'Le fichier dépasse la limite du formulaire',
        UPLOAD_ERR_PARTIAL => 'Le fichier a été partiellement uploadé',
        UPLOAD_ERR_NO_TMP_DIR => 'Dossier temporaire manquant',
        UPLOAD_ERR_CANT_WRITE => 'Échec d\'écriture sur le disque',
        UPLOAD_ERR_EXTENSION => 'Upload bloqué par une extension PHP'
    ];

    $errorMsg = $errorMessages[$file['error']] ?? 'Erreur inconnue lors de l\'upload';
    error_log("ERREUR: Upload error " . $file['error'] . ": " . $errorMsg);
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $errorMsg]);
    exit;
}

// Vérifier la taille du fichier
if ($file['size'] > $maxFileSize) {
    error_log("ERREUR: File too large: " . $file['size']);
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Fichier trop volumineux (max 20 MB)']);
    exit;
}

// Vérifier le type MIME
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

error_log("MIME type detected: " . $mimeType);

if (!in_array($mimeType, $allowedMimeTypes)) {
    error_log("ERREUR: Invalid MIME type");
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Type de fichier non autorisé (' . $mimeType . ')']);
    exit;
}

// Vérifier l'extension
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExtensions)) {
    error_log("ERREUR: Invalid extension: " . $ext);
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Extension de fichier non autorisée (.' . $ext . ')']);
    exit;
}

// Vérifier que c'est bien une image
$imageInfo = @getimagesize($file['tmp_name']);
if ($imageInfo === false) {
    error_log("ERREUR: Not a valid image");
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Le fichier n\'est pas une image valide']);
    exit;
}

error_log("Image validated: " . $imageInfo[0] . "x" . $imageInfo[1]);

// Créer le dossier photos s'il n'existe pas
if (!is_dir($uploadDir)) {
    error_log("Creating photos directory");
    if (!mkdir($uploadDir, 0775, true)) {
        error_log("ERREUR: Cannot create photos directory");
        http_response_code(500);
        echo json_encode(['success' => false, 'error' => 'Impossible de créer le dossier photos']);
        exit;
    }
}

// Vérifier les permissions d'écriture
if (!is_writable($uploadDir)) {
    error_log("ERREUR: photos directory not writable");
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Le dossier photos n\'est pas en écriture']);
    exit;
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

error_log("Target path: " . $targetPath);

// Déplacer le fichier uploadé
if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    error_log("ERREUR: Cannot move uploaded file");
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Échec de l\'enregistrement du fichier']);
    exit;
}

error_log("File moved successfully");

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

    error_log("Photo added to database with ID: " . $photoId);
    error_log("=== UPLOAD.PHP SUCCESS ===");

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

    error_log("ERREUR: Database error: " . $e->getMessage());
    error_log("=== UPLOAD.PHP ERROR ===");
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Erreur lors de l\'enregistrement en base de données: ' . $e->getMessage()]);
}
