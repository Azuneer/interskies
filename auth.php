<?php
/**
 * Gestion de l'authentification
 */

require_once __DIR__ . '/config/database.php';

// Configuration des sessions sécurisées
ini_set('session.cookie_httponly', 1);
ini_set('session.use_only_cookies', 1);
ini_set('session.cookie_samesite', 'Strict');

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

/**
 * Vérifier si l'utilisateur est connecté
 */
function isLoggedIn() {
    return isset($_SESSION['user_id']) && isset($_SESSION['username']);
}

/**
 * Exiger une authentification (rediriger vers login sinon)
 */
function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: login.php');
        exit;
    }
}

/**
 * Connexion de l'utilisateur
 */
function login($username, $password) {
    $db = getDB();

    $stmt = $db->prepare("SELECT id, username, password_hash FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password_hash'])) {
        // Régénérer l'ID de session pour éviter la fixation de session
        session_regenerate_id(true);

        $_SESSION['user_id'] = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['last_activity'] = time();

        return true;
    }

    return false;
}

/**
 * Déconnexion de l'utilisateur
 */
function logout() {
    $_SESSION = [];

    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $params["path"], $params["domain"],
            $params["secure"], $params["httponly"]
        );
    }

    session_destroy();
}

/**
 * Vérifier et rafraîchir la session (timeout après 30 minutes d'inactivité)
 */
function checkSessionTimeout() {
    $timeout = 1800; // 30 minutes

    if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > $timeout)) {
        logout();
        header('Location: login.php?timeout=1');
        exit;
    }

    $_SESSION['last_activity'] = time();
}

// Vérifier le timeout à chaque chargement de page
if (isLoggedIn()) {
    checkSessionTimeout();
}

/**
 * Changer le mot de passe d'un utilisateur
 */
function changePassword($username, $newPassword) {
    $db = getDB();

    $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);

    $stmt = $db->prepare("UPDATE users SET password_hash = ? WHERE username = ?");
    return $stmt->execute([$passwordHash, $username]);
}

// Gérer les actions de login/logout via POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        if ($_POST['action'] === 'login' && isset($_POST['username']) && isset($_POST['password'])) {
            $username = trim($_POST['username']);
            $password = $_POST['password'];

            if (login($username, $password)) {
                header('Location: admin.php');
                exit;
            } else {
                header('Location: login.php?error=1');
                exit;
            }
        } elseif ($_POST['action'] === 'logout') {
            logout();
            header('Location: index.php');
            exit;
        }
    }
}
?>
