<?php
header('Content-Type: application/json');

// Démarrer la session pour suivre les likes
session_start();

require_once __DIR__ . '/../config/database.php';

$db = getDB();

// Générer un session_id unique si pas déjà existant
if (!isset($_SESSION['like_session_id'])) {
    $_SESSION['like_session_id'] = bin2hex(random_bytes(16));
}

$sessionId = $_SESSION['like_session_id'];

// Récupérer la méthode HTTP
$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        case 'GET':
            // Récupérer les likes d'une photo
            $photoId = $_GET['photo_id'] ?? null;

            if (!$photoId) {
                http_response_code(400);
                echo json_encode(['error' => 'photo_id est requis']);
                exit;
            }

            // Compter les likes
            $stmt = $db->prepare("SELECT COUNT(*) FROM likes WHERE photo_id = ?");
            $stmt->execute([$photoId]);
            $likeCount = $stmt->fetchColumn();

            // Vérifier si la session actuelle a liké cette photo
            $stmt = $db->prepare("SELECT COUNT(*) FROM likes WHERE photo_id = ? AND session_id = ?");
            $stmt->execute([$photoId, $sessionId]);
            $hasLiked = $stmt->fetchColumn() > 0;

            echo json_encode([
                'photo_id' => (int)$photoId,
                'like_count' => (int)$likeCount,
                'has_liked' => $hasLiked
            ]);
            break;

        case 'POST':
            // Toggle like (ajouter ou retirer)
            $data = json_decode(file_get_contents('php://input'), true);

            if (!isset($data['photo_id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'photo_id est requis']);
                exit;
            }

            $photoId = (int)$data['photo_id'];

            // Vérifier que la photo existe
            $stmt = $db->prepare("SELECT COUNT(*) FROM photos WHERE id = ?");
            $stmt->execute([$photoId]);
            $photoExists = $stmt->fetchColumn() > 0;

            if (!$photoExists) {
                http_response_code(404);
                echo json_encode(['error' => 'Photo non trouvée']);
                exit;
            }

            // Vérifier si déjà liké
            $stmt = $db->prepare("SELECT id FROM likes WHERE photo_id = ? AND session_id = ?");
            $stmt->execute([$photoId, $sessionId]);
            $existingLike = $stmt->fetch();

            if ($existingLike) {
                // Retirer le like
                $stmt = $db->prepare("DELETE FROM likes WHERE id = ?");
                $stmt->execute([$existingLike['id']]);
                $action = 'unliked';
            } else {
                // Ajouter le like
                $stmt = $db->prepare("INSERT INTO likes (photo_id, session_id) VALUES (?, ?)");
                $stmt->execute([$photoId, $sessionId]);
                $action = 'liked';
            }

            // Récupérer le nouveau compte de likes
            $stmt = $db->prepare("SELECT COUNT(*) FROM likes WHERE photo_id = ?");
            $stmt->execute([$photoId]);
            $likeCount = $stmt->fetchColumn();

            echo json_encode([
                'success' => true,
                'action' => $action,
                'photo_id' => $photoId,
                'like_count' => (int)$likeCount,
                'has_liked' => ($action === 'liked')
            ]);
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
