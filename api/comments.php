<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/database.php';

$db = getDB();

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

            $stmt = $db->prepare("SELECT * FROM comments WHERE photo_id = ? ORDER BY created_at DESC");
            $stmt->execute([$photoId]);
            $photoComments = $stmt->fetchAll();

            echo json_encode($photoComments);
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
            $stmt = $db->prepare("SELECT COUNT(*) FROM photos WHERE id = ?");
            $stmt->execute([$data['photo_id']]);
            $photoExists = $stmt->fetchColumn() > 0;

            if (!$photoExists) {
                http_response_code(404);
                echo json_encode(['error' => 'Photo non trouvée']);
                exit;
            }

            $author = isset($data['author']) && trim($data['author']) !== ''
                ? trim($data['author'])
                : 'Anonyme';

            $stmt = $db->prepare("INSERT INTO comments (photo_id, content, author) VALUES (?, ?, ?)");
            $stmt->execute([
                (int)$data['photo_id'],
                trim($data['content']),
                $author
            ]);

            $newId = $db->lastInsertId();
            $stmt = $db->prepare("SELECT * FROM comments WHERE id = ?");
            $stmt->execute([$newId]);
            $newComment = $stmt->fetch();

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

            $updateFields = ['content = ?'];
            $updateParams = [trim($data['content'])];

            if (isset($data['author']) && trim($data['author']) !== '') {
                $updateFields[] = 'author = ?';
                $updateParams[] = trim($data['author']);
            }

            $updateParams[] = $data['id'];

            $stmt = $db->prepare("UPDATE comments SET " . implode(', ', $updateFields) . " WHERE id = ?");
            $stmt->execute($updateParams);

            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Commentaire non trouvé']);
                exit;
            }

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

            $stmt = $db->prepare("DELETE FROM comments WHERE id = ?");
            $stmt->execute([$data['id']]);

            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                echo json_encode(['error' => 'Commentaire non trouvé']);
                exit;
            }

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
