<?php
header('Content-Type: application/json');

// Configuration
$dataDir = __DIR__ . '/../data';
$commentsFile = $dataDir . '/comments.json';
$photosFile = $dataDir . '/photos.json';

// Créer le dossier data s'il n'existe pas
if (!is_dir($dataDir)) {
    mkdir($dataDir, 0777, true);
}

// Initialiser les fichiers JSON s'ils n'existent pas
if (!file_exists($commentsFile)) {
    file_put_contents($commentsFile, json_encode([], JSON_PRETTY_PRINT));
}
if (!file_exists($photosFile)) {
    file_put_contents($photosFile, json_encode([], JSON_PRETTY_PRINT));
}

// Fonctions utilitaires
function loadComments() {
    global $commentsFile;
    $data = file_get_contents($commentsFile);
    return json_decode($data, true) ?: [];
}

function saveComments($comments) {
    global $commentsFile;
    file_put_contents($commentsFile, json_encode(array_values($comments), JSON_PRETTY_PRINT));
}

function loadPhotos() {
    global $photosFile;
    $data = file_get_contents($photosFile);
    return json_decode($data, true) ?: [];
}

// Récupérer la méthode HTTP
$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        case 'GET':
            // Récupérer les commentaires d'une photo
            $photoId = $_GET['photo_id'] ?? null;

            if (!$photoId) {
                http_response_code(400);
                echo json_encode(['error' => 'photo_id est requis']);
                exit;
            }

            $comments = loadComments();
            $photoComments = array_filter($comments, function($c) use ($photoId) {
                return $c['photo_id'] == $photoId;
            });

            // Trier par date de création
            usort($photoComments, function($a, $b) {
                return strcmp($b['created_at'], $a['created_at']);
            });

            echo json_encode(array_values($photoComments));
            break;

        case 'POST':
            // Ajouter un nouveau commentaire
            $data = json_decode(file_get_contents('php://input'), true);

            if (!isset($data['photo_id']) || !isset($data['content'])) {
                http_response_code(400);
                echo json_encode(['error' => 'photo_id et content sont requis']);
                exit;
            }

            // Vérifier que la photo existe
            $photos = loadPhotos();
            $photoExists = false;
            foreach ($photos as $photo) {
                if ($photo['id'] == $data['photo_id']) {
                    $photoExists = true;
                    break;
                }
            }

            if (!$photoExists) {
                http_response_code(404);
                echo json_encode(['error' => 'Photo non trouvée']);
                exit;
            }

            $comments = loadComments();

            // Générer un nouvel ID
            $newId = empty($comments) ? 1 : max(array_column($comments, 'id')) + 1;

            $newComment = [
                'id' => $newId,
                'photo_id' => (int)$data['photo_id'],
                'content' => trim($data['content']),
                'author' => isset($data['author']) && trim($data['author']) !== ''
                    ? trim($data['author'])
                    : 'Anonyme',
                'created_at' => date('Y-m-d H:i:s')
            ];

            $comments[] = $newComment;
            saveComments($comments);

            http_response_code(201);
            echo json_encode($newComment);
            break;

        case 'PUT':
            // Modifier un commentaire existant
            $data = json_decode(file_get_contents('php://input'), true);

            if (!isset($data['id']) || !isset($data['content'])) {
                http_response_code(400);
                echo json_encode(['error' => 'id et content sont requis']);
                exit;
            }

            $comments = loadComments();
            $found = false;

            foreach ($comments as &$comment) {
                if ($comment['id'] == $data['id']) {
                    $comment['content'] = trim($data['content']);
                    if (isset($data['author']) && trim($data['author']) !== '') {
                        $comment['author'] = trim($data['author']);
                    }
                    $found = true;
                    break;
                }
            }

            if (!$found) {
                http_response_code(404);
                echo json_encode(['error' => 'Commentaire non trouvé']);
                exit;
            }

            saveComments($comments);
            echo json_encode(['success' => true]);
            break;

        case 'DELETE':
            // Supprimer un commentaire
            $data = json_decode(file_get_contents('php://input'), true);

            if (!isset($data['id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'id est requis']);
                exit;
            }

            $comments = loadComments();
            $initialCount = count($comments);

            $comments = array_filter($comments, function($c) use ($data) {
                return $c['id'] != $data['id'];
            });

            if (count($comments) === $initialCount) {
                http_response_code(404);
                echo json_encode(['error' => 'Commentaire non trouvé']);
                exit;
            }

            saveComments($comments);
            echo json_encode(['success' => true]);
            break;

        default:
            http_response_code(405);
            echo json_encode(['error' => 'Méthode non autorisée']);
            break;
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Erreur serveur : ' . $e->getMessage()]);
}
?>
