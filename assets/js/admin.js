// Mot de passe admin (à changer en production)
const ADMIN_PASSWORD = 'admin123';

// Toggle admin mode
document.getElementById('admin-toggle').addEventListener('click', function() {
    const passwordDiv = document.getElementById('admin-password');

    if (passwordDiv.style.display === 'none') {
        passwordDiv.style.display = 'flex';
    } else {
        passwordDiv.style.display = 'none';
    }
});

// Vérifier le mot de passe
function checkPassword() {
    const password = document.getElementById('password-input').value;

    if (password === ADMIN_PASSWORD) {
        // Activer le mode admin
        isAdminMode = true;

        // Afficher les boutons de gestion des commentaires
        document.querySelectorAll('.btn-manage-comments').forEach(btn => {
            btn.style.display = 'block';
        });

        // Mettre à jour le bouton admin
        const adminToggle = document.getElementById('admin-toggle');
        adminToggle.textContent = '🔓 Mode Admin Actif';
        adminToggle.style.backgroundColor = '#00d4ff';
        adminToggle.style.color = '#0a0a0a';

        // Cacher le champ de mot de passe
        document.getElementById('admin-password').style.display = 'none';
        document.getElementById('password-input').value = '';

        // Afficher les actions dans les commentaires si le modal est ouvert
        document.querySelectorAll('.comment-actions').forEach(actions => {
            actions.style.display = 'flex';
        });

        alert('Mode admin activé !');
    } else {
        alert('Mot de passe incorrect !');
    }
}

// Permettre de valider avec Enter
document.getElementById('password-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        checkPassword();
    }
});
