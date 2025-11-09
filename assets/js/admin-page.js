// Fonctions pour la page d'administration

// Détection automatique du mode jour/nuit
function setThemeBasedOnTime() {
    const currentHour = new Date().getHours();

    // Mode sombre de 19h à 7h
    if (currentHour >= 19 || currentHour < 7) {
        document.body.classList.add('dark-mode');
    } else {
        document.body.classList.remove('dark-mode');
    }
}

// Initialisation au chargement de la page
document.addEventListener('DOMContentLoaded', function() {
    // Appliquer le thème selon l'heure
    setThemeBasedOnTime();

    // Vérifier et mettre à jour le thème toutes les minutes
    setInterval(setThemeBasedOnTime, 60000);
});

// Ouvrir le modal pour ajouter un commentaire
function showAddCommentForm(photoId) {
    const modal = document.getElementById('comment-modal');
    const modalTitle = document.getElementById('modal-title');

    modalTitle.textContent = 'Ajouter un commentaire';

    document.getElementById('form-photo-id').value = photoId;
    document.getElementById('form-comment-id').value = '';
    document.getElementById('form-author').value = '';
    document.getElementById('form-content').value = '';

    modal.style.display = 'block';
}

// Fermer le modal
function closeCommentModal() {
    const modal = document.getElementById('comment-modal');
    modal.style.display = 'none';

    // Réinitialiser le formulaire
    document.getElementById('form-photo-id').value = '';
    document.getElementById('form-comment-id').value = '';
    document.getElementById('form-author').value = '';
    document.getElementById('form-content').value = '';
}

// Soumettre le formulaire de commentaire
function submitCommentForm() {
    const photoId = document.getElementById('form-photo-id').value;
    const commentId = document.getElementById('form-comment-id').value;
    const author = document.getElementById('form-author').value.trim() || 'Anonyme';
    const content = document.getElementById('form-content').value.trim();

    if (!content) {
        alert('Veuillez entrer un commentaire.');
        return;
    }

    if (commentId) {
        // Modifier un commentaire existant
        updateComment(commentId, author, content);
    } else {
        // Ajouter un nouveau commentaire
        addComment(photoId, author, content);
    }
}

// Ajouter un nouveau commentaire
function addComment(photoId, author, content) {
    fetch('api/comments.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            photo_id: photoId,
            author: author,
            content: content
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Recharger la page pour afficher le nouveau commentaire
        location.reload();
    })
    .catch(error => {
        console.error('Erreur lors de l\'ajout du commentaire:', error);
        alert('Erreur lors de l\'ajout du commentaire.');
    });
}

// Modifier un commentaire
function editComment(commentId, photoId) {
    // Récupérer le texte actuel du commentaire
    const commentElement = document.querySelector(`.comment-text-${commentId}`);
    if (!commentElement) {
        alert('Commentaire introuvable');
        return;
    }

    const currentContent = commentElement.textContent;

    // Ouvrir le modal en mode édition
    const modal = document.getElementById('comment-modal');
    const modalTitle = document.getElementById('modal-title');

    modalTitle.textContent = 'Modifier le commentaire';

    document.getElementById('form-photo-id').value = photoId;
    document.getElementById('form-comment-id').value = commentId;
    document.getElementById('form-author').value = ''; // On ne peut pas facilement récupérer l'auteur
    document.getElementById('form-content').value = currentContent;

    modal.style.display = 'block';
}

// Mettre à jour un commentaire
function updateComment(commentId, author, content) {
    fetch('api/comments.php', {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: commentId,
            author: author,
            content: content
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Recharger la page pour afficher les modifications
        location.reload();
    })
    .catch(error => {
        console.error('Erreur lors de la modification du commentaire:', error);
        alert('Erreur lors de la modification du commentaire.');
    });
}

// Supprimer un commentaire
function deleteComment(commentId, photoId) {
    if (!confirm('Êtes-vous sûr de vouloir supprimer ce commentaire ?')) {
        return;
    }

    fetch('api/comments.php', {
        method: 'DELETE',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: commentId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Recharger la page pour refléter la suppression
        location.reload();
    })
    .catch(error => {
        console.error('Erreur lors de la suppression du commentaire:', error);
        alert('Erreur lors de la suppression du commentaire.');
    });
}

// Fermer le modal en cliquant en dehors
window.addEventListener('click', function(e) {
    const modal = document.getElementById('comment-modal');
    if (e.target === modal) {
        closeCommentModal();
    }
});

// Fermer le modal avec Échap
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeCommentModal();
    }
});
