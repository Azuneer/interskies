<?php
require_once __DIR__ . '/auth.php';

// Si déjà connecté, rediriger vers admin
if (isLoggedIn()) {
    header('Location: admin.php');
    exit;
}

$error = isset($_GET['error']) ? true : false;
$timeout = isset($_GET['timeout']) ? true : false;
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Connexion - Interskies</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="icon" type="image/png" href="/favicon.png">
    <link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
    <style>
        .login-container {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .login-box {
            background-color: var(--bg-card);
            border: 4px solid var(--border-color);
            padding: 40px;
            max-width: 450px;
            width: 100%;
            box-shadow: 8px 8px 0 var(--shadow-color);
        }

        .login-title {
            font-family: 'Space Mono', monospace;
            font-size: 28px;
            font-weight: 700;
            color: var(--text-primary);
            text-align: center;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }

        .login-subtitle {
            text-align: center;
            color: var(--text-secondary);
            font-size: 13px;
            margin-bottom: 30px;
        }

        .login-subtitle::before {
            content: '~ ';
            color: var(--accent-purple);
        }

        .login-subtitle::after {
            content: ' ~';
            color: var(--accent-purple);
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-group label {
            display: block;
            font-size: 13px;
            color: var(--text-secondary);
            margin-bottom: 8px;
            font-weight: 700;
            text-transform: uppercase;
        }

        .form-group input {
            width: 100%;
            padding: 15px;
            background-color: var(--bg-secondary);
            color: var(--text-primary);
            border: 3px solid var(--border-color);
            font-family: 'Space Mono', monospace;
            font-size: 14px;
            transition: all 0.3s;
        }

        .form-group input:focus {
            outline: none;
            border-color: var(--accent-purple);
            box-shadow: 3px 3px 0 var(--accent-purple);
        }

        .btn-login {
            width: 100%;
            padding: 15px;
            background-color: var(--border-color);
            color: var(--bg-card);
            border: 3px solid var(--border-color);
            font-family: 'Space Mono', monospace;
            font-size: 14px;
            font-weight: 700;
            cursor: pointer;
            text-transform: uppercase;
            letter-spacing: 1px;
            box-shadow: 4px 4px 0 var(--shadow-color);
            transition: all 0.2s;
        }

        .btn-login:hover {
            background-color: var(--accent-purple);
            border-color: var(--accent-purple);
            transform: translate(2px, 2px);
            box-shadow: 2px 2px 0 var(--shadow-color);
        }

        .btn-login:active {
            transform: translate(4px, 4px);
            box-shadow: none;
        }

        .error-message {
            background-color: var(--accent-pink);
            color: var(--text-primary);
            padding: 12px 15px;
            border: 3px solid var(--border-color);
            margin-bottom: 20px;
            text-align: center;
            font-size: 13px;
            font-weight: 700;
        }

        .back-link {
            display: block;
            text-align: center;
            margin-top: 20px;
            color: var(--text-secondary);
            text-decoration: none;
            font-size: 13px;
        }

        .back-link:hover {
            color: var(--accent-purple);
        }

        .back-link::before {
            content: '← ';
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="login-box">
            <h1 class="login-title">Interskies</h1>
            <p class="login-subtitle">Administration</p>

            <?php if ($error): ?>
                <div class="error-message">
                    ✦ Identifiants incorrects
                </div>
            <?php endif; ?>

            <?php if ($timeout): ?>
                <div class="error-message">
                    ✦ Session expirée, veuillez vous reconnecter
                </div>
            <?php endif; ?>

            <form method="POST" action="auth.php">
                <input type="hidden" name="action" value="login">

                <div class="form-group">
                    <label for="username">Nom d'utilisateur</label>
                    <input type="text" id="username" name="username" required autofocus>
                </div>

                <div class="form-group">
                    <label for="password">Mot de passe</label>
                    <input type="password" id="password" name="password" required>
                </div>

                <button type="submit" class="btn-login">Se connecter</button>
            </form>

            <a href="index.php" class="back-link">Retour à la galerie</a>
        </div>
    </div>

    <script src="assets/js/script.js"></script>
</body>
</html>
