// Variables globales
let currentPhotoId = null;
let isAdminMode = false;

// Initialisation au chargement de la page
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();
});

// Configuration des écouteurs d'événements
function setupEventListeners() {
    // Clic sur les photos pour ouvrir le modal de commentaires
    document.querySelectorAll('.photo-item').forEach(photoItem => {
        photoItem.addEventListener('click', function(e) {
            if (e.target.classList.contains('btn-manage-comments')) return;

            const photoId = this.dataset.id;
            const photoName = this.querySelector('.photo-name').textContent;

            openCommentsModal(photoId, photoName);
        });
    });

    // Boutons de gestion des commentaires (pour le mode admin)
    document.querySelectorAll('.btn-manage-comments').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const photoId = this.dataset.photoId;
            const photoItem = this.closest('.photo-item');
            const photoName = photoItem.querySelector('.photo-name').textContent;

            openCommentsModal(photoId, photoName);
        });
    });

    // Fermer le modal
    const modalClose = document.querySelector('.modal-close');
    if (modalClose) {
        modalClose.addEventListener('click', closeCommentsModal);
    }

    // Fermer le modal en cliquant en dehors
    const modal = document.getElementById('comments-modal');
    if (modal) {
        modal.addEventListener('click', function(e) {
            if (e.target === modal) {
                closeCommentsModal();
            }
        });
    }

    // Échap pour fermer le modal
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeCommentsModal();
        }
    });
}

// Ouvrir le modal de commentaires
function openCommentsModal(photoId, photoName) {
    currentPhotoId = photoId;

    const modal = document.getElementById('comments-modal');
    const modalTitle = document.getElementById('modal-photo-title');

    modalTitle.textContent = `Commentaires - ${photoName}`;

    loadComments(photoId);

    modal.style.display = 'block';
}

// Fermer le modal de commentaires
function closeCommentsModal() {
    const modal = document.getElementById('comments-modal');
    modal.style.display = 'none';

    currentPhotoId = null;

    // Réinitialiser le formulaire
    document.getElementById('comment-content').value = '';
    document.getElementById('comment-author').value = '';
}

// Charger les commentaires
function loadComments(photoId) {
    fetch(`api/comments.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(comments => {
            const commentsList = document.getElementById('comments-list');

            if (comments.length === 0) {
                commentsList.innerHTML = '<p style="color: #888; text-align: center; padding: 20px;">Aucun commentaire pour cette photo.</p>';
                return;
            }

            let html = '';
            comments.forEach(comment => {
                html += `
                    <div class="comment" data-comment-id="${comment.id}">
                        <div class="comment-header">
                            <span class="comment-author">${escapeHtml(comment.author)}</span>
                            <span class="comment-date">${formatDate(comment.created_at)}</span>
                        </div>
                        <div class="comment-content">${escapeHtml(comment.content)}</div>
                        <div class="comment-actions" style="display: ${isAdminMode ? 'flex' : 'none'}">
                            <button class="btn-edit" onclick="editComment(${comment.id}, '${escapeHtml(comment.content)}', '${escapeHtml(comment.author)}')">Modifier</button>
                            <button class="btn-delete" onclick="deleteComment(${comment.id})">Supprimer</button>
                        </div>
                    </div>
                `;
            });

            commentsList.innerHTML = html;
        })
        .catch(error => {
            console.error('Erreur lors du chargement des commentaires:', error);
            const commentsList = document.getElementById('comments-list');
            commentsList.innerHTML = '<p style="color: #ff4444; text-align: center; padding: 20px;">Erreur lors du chargement des commentaires.</p>';
        });
}

// Ajouter un commentaire
function addComment() {
    const content = document.getElementById('comment-content').value.trim();
    const author = document.getElementById('comment-author').value.trim() || 'Anonyme';

    if (!content) {
        alert('Veuillez entrer un commentaire.');
        return;
    }

    if (!currentPhotoId) {
        alert('Erreur: Aucune photo sélectionnée.');
        return;
    }

    fetch('api/comments.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            photo_id: currentPhotoId,
            content: content,
            author: author
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Recharger les commentaires
        loadComments(currentPhotoId);

        // Réinitialiser le formulaire
        document.getElementById('comment-content').value = '';
        document.getElementById('comment-author').value = '';

        // Mettre à jour le compteur sur la photo
        updateCommentCount(currentPhotoId);
    })
    .catch(error => {
        console.error('Erreur lors de l\'ajout du commentaire:', error);
        alert('Erreur lors de l\'ajout du commentaire.');
    });
}

// Modifier un commentaire
function editComment(commentId, currentContent, currentAuthor) {
    const newContent = prompt('Modifier le commentaire:', currentContent);

    if (newContent === null || newContent.trim() === '') {
        return;
    }

    fetch('api/comments.php', {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: commentId,
            content: newContent.trim(),
            author: currentAuthor
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Recharger les commentaires
        loadComments(currentPhotoId);
    })
    .catch(error => {
        console.error('Erreur lors de la modification du commentaire:', error);
        alert('Erreur lors de la modification du commentaire.');
    });
}

// Supprimer un commentaire
function deleteComment(commentId) {
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

        // Recharger les commentaires
        loadComments(currentPhotoId);

        // Mettre à jour le compteur sur la photo
        updateCommentCount(currentPhotoId);
    })
    .catch(error => {
        console.error('Erreur lors de la suppression du commentaire:', error);
        alert('Erreur lors de la suppression du commentaire.');
    });
}

// Mettre à jour le compteur de commentaires
function updateCommentCount(photoId) {
    fetch(`api/comments.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(comments => {
            const photoItem = document.querySelector(`.photo-item[data-id="${photoId}"]`);
            if (!photoItem) return;

            let countElement = photoItem.querySelector('.photo-comment-count');

            if (comments.length === 0) {
                if (countElement) {
                    countElement.remove();
                }
            } else {
                if (!countElement) {
                    countElement = document.createElement('div');
                    countElement.className = 'photo-comment-count';
                    photoItem.appendChild(countElement);
                }
                countElement.textContent = `💬 ${comments.length}`;
            }
        })
        .catch(error => {
            console.error('Erreur lors de la mise à jour du compteur:', error);
        });
}

// Fonctions utilitaires
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;

    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'À l\'instant';
    if (minutes < 60) return `Il y a ${minutes} min`;
    if (hours < 24) return `Il y a ${hours}h`;
    if (days < 7) return `Il y a ${days}j`;

    return date.toLocaleDateString('fr-FR', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
    });
}
