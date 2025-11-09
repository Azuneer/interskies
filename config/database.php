<?php
/**
 * Configuration de la base de données
 */

define('DB_PATH', __DIR__ . '/../database/interskies.db');

/**
 * Obtenir la connexion PDO à la base de données
 */
function getDB() {
    try {
        $db = new PDO('sqlite:' . DB_PATH);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

        // Activer les foreign keys
        $db->exec('PRAGMA foreign_keys = ON');

        return $db;
    } catch (PDOException $e) {
        die('Erreur de connexion à la base de données : ' . $e->getMessage());
    }
}

/**
 * Initialiser la base de données avec les tables
 */
function initDB() {
    $db = getDB();

    // Table users
    $db->exec("CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )");

    // Table photos
    $db->exec("CREATE TABLE IF NOT EXISTS photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL UNIQUE,
        title TEXT,
        description TEXT,
        width INTEGER,
        height INTEGER,
        size INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )");

    // Table comments
    $db->exec("CREATE TABLE IF NOT EXISTS comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        author TEXT DEFAULT 'Anonyme',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
    )");

    // Créer l'utilisateur admin par défaut si n'existe pas
    $stmt = $db->prepare("SELECT COUNT(*) FROM users WHERE username = ?");
    $stmt->execute(['admin']);

    if ($stmt->fetchColumn() == 0) {
        // Mot de passe par défaut : admin123 (À CHANGER EN PRODUCTION!)
        $defaultPassword = password_hash('admin123', PASSWORD_DEFAULT);
        $stmt = $db->prepare("INSERT INTO users (username, password_hash) VALUES (?, ?)");
        $stmt->execute(['admin', $defaultPassword]);
    }

    return $db;
}

// Créer le dossier database s'il n'existe pas
$dbDir = dirname(DB_PATH);
if (!is_dir($dbDir)) {
    mkdir($dbDir, 0755, true);
}

// Initialiser la base de données
initDB();
?>
