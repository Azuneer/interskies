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
            // Récupérer les likes d'un commentaire
            $commentId = $_GET['comment_id'] ?? null;

            if (!$commentId) {
                http_response_code(400);
                echo json_encode(['error' => 'comment_id est requis']);
                exit;
            }

            // Compter les likes
            $stmt = $db->prepare("SELECT COUNT(*) FROM comment_likes WHERE comment_id = ?");
            $stmt->execute([$commentId]);
            $likeCount = $stmt->fetchColumn();

            // Vérifier si la session actuelle a liké ce commentaire
            $stmt = $db->prepare("SELECT COUNT(*) FROM comment_likes WHERE comment_id = ? AND session_id = ?");
            $stmt->execute([$commentId, $sessionId]);
            $hasLiked = $stmt->fetchColumn() > 0;

            echo json_encode([
                'comment_id' => (int)$commentId,
                'like_count' => (int)$likeCount,
                'has_liked' => $hasLiked
            ]);
            break;

        case 'POST':
            // Toggle like (ajouter ou retirer)
            $data = json_decode(file_get_contents('php://input'), true);

            if (!isset($data['comment_id'])) {
                http_response_code(400);
                echo json_encode(['error' => 'comment_id est requis']);
                exit;
            }

            $commentId = (int)$data['comment_id'];

            // Vérifier que le commentaire existe
            $stmt = $db->prepare("SELECT COUNT(*) FROM comments WHERE id = ?");
            $stmt->execute([$commentId]);
            $commentExists = $stmt->fetchColumn() > 0;

            if (!$commentExists) {
                http_response_code(404);
                echo json_encode(['error' => 'Commentaire non trouvé']);
                exit;
            }

            // Vérifier si déjà liké
            $stmt = $db->prepare("SELECT id FROM comment_likes WHERE comment_id = ? AND session_id = ?");
            $stmt->execute([$commentId, $sessionId]);
            $existingLike = $stmt->fetch();

            if ($existingLike) {
                // Retirer le like
                $stmt = $db->prepare("DELETE FROM comment_likes WHERE id = ?");
                $stmt->execute([$existingLike['id']]);
                $action = 'unliked';
            } else {
                // Ajouter le like
                $stmt = $db->prepare("INSERT INTO comment_likes (comment_id, session_id) VALUES (?, ?)");
                $stmt->execute([$commentId, $sessionId]);
                $action = 'liked';
            }

            // Récupérer le nouveau compte de likes
            $stmt = $db->prepare("SELECT COUNT(*) FROM comment_likes WHERE comment_id = ?");
            $stmt->execute([$commentId]);
            $likeCount = $stmt->fetchColumn();

            echo json_encode([
                'success' => true,
                'action' => $action,
                'comment_id' => $commentId,
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
