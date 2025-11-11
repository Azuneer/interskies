// Variables globales
let currentPhotoId = null;
let isAdminMode = false;
let currentReplyToId = null; // Pour stocker l'ID du commentaire auquel on répond

// ============================================
// Son au survol des photos
// ============================================

const hoverSound = new Audio('assets/sounds/click.wav');
hoverSound.volume = 0.3;
hoverSound.preload = 'auto';

let audioUnlocked = false;

function unlockAudio() {
    if (audioUnlocked) return;
    
    hoverSound.play().then(() => {
        hoverSound.pause();
        hoverSound.currentTime = 0;
        audioUnlocked = true;
    }).catch(() => {});
}

document.body.addEventListener('click', unlockAudio, { once: true });
document.body.addEventListener('touchstart', unlockAudio, { once: true });

function playHoverSound() {
    if (!audioUnlocked) return;
    
    hoverSound.currentTime = 0;
    hoverSound.play().catch(() => {});
}

document.addEventListener('DOMContentLoaded', () => {
    const photoItems = document.querySelectorAll('.photo-item');
    
    photoItems.forEach(item => {
        item.addEventListener('mouseenter', playHoverSound);
    });
});

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

    setupEventListeners();
});

// Configuration des écouteurs d'événements
function setupEventListeners() {
    // Clic sur les photos pour ouvrir le modal de commentaires
    document.querySelectorAll('.photo-item').forEach(photoItem => {
        photoItem.addEventListener('mouseenter', playHoverSound);
        photoItem.addEventListener('click', function() {
            const photoId = this.dataset.id;
            const filename = this.dataset.filename;
            const imgSrc = this.querySelector('img').src;

            openCommentsModal(photoId, filename, imgSrc);
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
function openCommentsModal(photoId, filename, imgSrc) {
    currentPhotoId = photoId;

    const modal = document.getElementById('comments-modal');
    const modalPhotoImg = document.getElementById('modal-photo-img');
    const modalPhotoFilename = document.getElementById('modal-photo-filename');
    const modalTitle = document.getElementById('modal-photo-title');

    // Définir l'image
    modalPhotoImg.src = imgSrc;
    modalPhotoImg.alt = filename;

    // Définir le nom du fichier
    modalPhotoFilename.textContent = filename;

    // Définir le titre
    modalTitle.textContent = 'Commentaires';

    // Charger les commentaires
    loadComments(photoId);

    // Charger les likes
    loadLikes(photoId);

    // Afficher le modal
    modal.style.display = 'block';
}

// Fermer le modal de commentaires
function closeCommentsModal() {
    const modal = document.getElementById('comments-modal');
    modal.style.display = 'none';

    currentPhotoId = null;

    // Réinitialiser le formulaire et son état
    hideCommentForm();

    // Réinitialiser l'image
    document.getElementById('modal-photo-img').src = '';
    document.getElementById('modal-photo-filename').textContent = '';
}

// Organiser les commentaires en arbre
function buildCommentTree(comments) {
    const commentMap = {};
    const rootComments = [];

    // Créer un map de tous les commentaires
    comments.forEach(comment => {
        comment.replies = [];
        commentMap[comment.id] = comment;
    });

    // Organiser en arbre
    comments.forEach(comment => {
        if (comment.parent_id === null) {
            rootComments.push(comment);
        } else {
            if (commentMap[comment.parent_id]) {
                commentMap[comment.parent_id].replies.push(comment);
            }
        }
    });

    return rootComments;
}

// Rendre l'HTML d'un commentaire et ses réponses
function renderComment(comment, level = 0) {
    const indent = level > 0 ? 'comment-reply' : '';
    const isReply = level > 0;
    const likeCount = comment.like_count || 0;

    let html = `
        <div class="comment ${indent}" data-comment-id="${comment.id}" style="${isReply ? 'margin-left: 35px;' : ''}">
            <div class="comment-header">
                <span class="comment-author">${escapeHtml(comment.author)}</span>
                <span class="comment-date">${formatDate(comment.created_at)}</span>
            </div>
            <div class="comment-content">${escapeHtml(comment.content)}</div>
            <div class="comment-footer">
                <button class="btn-comment-like" data-comment-id="${comment.id}" onclick="toggleCommentLike(${comment.id})">
                    <span class="comment-like-icon">🤍</span>
                    <span class="comment-like-count">${likeCount}</span>
                </button>
                <button class="btn-reply" onclick="replyToComment(${comment.id}, '${escapeHtml(comment.author).replace(/'/g, "\\'")}')">Répondre</button>
                <div class="comment-actions" style="display: ${isAdminMode ? 'inline-flex' : 'none'}">
                    <button class="btn-edit" onclick="editComment(${comment.id}, '${escapeHtml(comment.content).replace(/'/g, "\\'")}', '${escapeHtml(comment.author).replace(/'/g, "\\'")}')">Modifier</button>
                    <button class="btn-delete" onclick="deleteComment(${comment.id})">Supprimer</button>
                </div>
            </div>
        </div>
    `;

    // Ajouter les réponses récursivement
    if (comment.replies && comment.replies.length > 0) {
        comment.replies.forEach(reply => {
            html += renderComment(reply, level + 1);
        });
    }

    return html;
}

// Charger les commentaires
function loadComments(photoId) {
    fetch(`api/comments.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(comments => {
            const commentsList = document.getElementById('comments-list');

            if (comments.length === 0) {
                commentsList.innerHTML = '<p style="color: var(--text-muted); text-align: center; padding: 20px; font-size: 13px;">Aucun commentaire pour cette photo.</p>';
                return;
            }

            // Organiser en arbre
            const commentTree = buildCommentTree(comments);

            // Rendre l'HTML
            let html = '';
            commentTree.forEach(comment => {
                html += renderComment(comment);
            });

            commentsList.innerHTML = html;

            // Charger l'état des likes pour tous les commentaires
            loadAllCommentLikeStates(comments);
        })
        .catch(error => {
            console.error('Erreur lors du chargement des commentaires:', error);
            const commentsList = document.getElementById('comments-list');
            commentsList.innerHTML = '<p style="color: var(--accent-pink); text-align: center; padding: 20px; font-size: 13px;">Erreur lors du chargement des commentaires.</p>';
        });
}

// Charger l'état des likes pour tous les commentaires
function loadAllCommentLikeStates(comments) {
    comments.forEach(comment => {
        loadCommentLikeState(comment.id);
    });
}

// Charger l'état d'un like de commentaire
function loadCommentLikeState(commentId) {
    fetch(`api/comment_likes.php?comment_id=${commentId}`)
        .then(response => response.json())
        .then(data => {
            const commentLikeBtn = document.querySelector(`.btn-comment-like[data-comment-id="${commentId}"]`);
            if (!commentLikeBtn) return;

            const icon = commentLikeBtn.querySelector('.comment-like-icon');
            const count = commentLikeBtn.querySelector('.comment-like-count');

            count.textContent = data.like_count;

            if (data.has_liked) {
                icon.textContent = '❤️';
                commentLikeBtn.classList.add('liked');
            } else {
                icon.textContent = '🤍';
                commentLikeBtn.classList.remove('liked');
            }
        })
        .catch(error => {
            console.error('Erreur lors du chargement du like:', error);
        });
}

// Toggle like sur un commentaire
function toggleCommentLike(commentId) {
    fetch('api/comment_likes.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            comment_id: commentId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Mettre à jour le bouton
        const commentLikeBtn = document.querySelector(`.btn-comment-like[data-comment-id="${commentId}"]`);
        if (!commentLikeBtn) return;

        const icon = commentLikeBtn.querySelector('.comment-like-icon');
        const count = commentLikeBtn.querySelector('.comment-like-count');

        count.textContent = data.like_count;

        if (data.has_liked) {
            icon.textContent = '❤️';
            commentLikeBtn.classList.add('liked');
        } else {
            icon.textContent = '🤍';
            commentLikeBtn.classList.remove('liked');
        }

        // Recharger les commentaires pour mettre à jour l'ordre
        if (currentPhotoId) {
            loadComments(currentPhotoId);
        }
    })
    .catch(error => {
        console.error('Erreur lors du toggle du like:', error);
        alert('Erreur lors du like.');
    });
}

// Répondre à un commentaire
function replyToComment(commentId, authorName) {
    currentReplyToId = commentId;
    showCommentForm();

    // Mettre à jour le titre du formulaire pour indiquer qu'on répond
    const formTitle = document.querySelector('.comment-form h3');
    formTitle.innerHTML = `✦ Répondre à ${authorName}`;

    // Focus sur le textarea
    document.getElementById('comment-content').focus();
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

    const payload = {
        photo_id: currentPhotoId,
        content: content,
        author: author
    };

    // Ajouter parent_id si on répond à un commentaire
    if (currentReplyToId !== null) {
        payload.parent_id = currentReplyToId;
    }

    fetch('api/comments.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
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

        // Cacher le formulaire et réafficher le bouton
        hideCommentForm();

        // Mettre à jour le compteur sur la photo
        updateCommentCount(currentPhotoId);
    })
    .catch(error => {
        console.error('Erreur lors de l\'ajout du commentaire:', error);
        alert('Erreur lors de l\'ajout du commentaire.');
    });
}

// Afficher le formulaire de commentaire
function showCommentForm() {
    document.getElementById('show-comment-form-btn').style.display = 'none';
    document.getElementById('comment-form').style.display = 'block';
    // Focus sur le textarea
    document.getElementById('comment-content').focus();
}

// Cacher le formulaire de commentaire
function hideCommentForm() {
    document.getElementById('comment-form').style.display = 'none';
    document.getElementById('show-comment-form-btn').style.display = 'block';
    // Réinitialiser les champs
    document.getElementById('comment-content').value = '';
    document.getElementById('comment-author').value = '';
    // Réinitialiser le mode réponse
    currentReplyToId = null;
    const formTitle = document.querySelector('.comment-form h3');
    formTitle.innerHTML = '✦ Ajouter un commentaire';
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

// ============================================
// Gestion des Likes
// ============================================

// Charger les likes d'une photo
function loadLikes(photoId) {
    fetch(`api/likes.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(data => {
            const modalLikeBtn = document.getElementById('modal-like-btn');
            const modalLikeCount = document.getElementById('modal-like-count');
            const likeIcon = modalLikeBtn.querySelector('.like-icon');

            // Mettre à jour le compteur
            modalLikeCount.textContent = data.like_count;

            // Mettre à jour l'icône selon l'état
            if (data.has_liked) {
                likeIcon.textContent = '❤️';
                modalLikeBtn.classList.add('liked');
            } else {
                likeIcon.textContent = '🤍';
                modalLikeBtn.classList.remove('liked');
            }
        })
        .catch(error => {
            console.error('Erreur lors du chargement des likes:', error);
        });
}

// Toggle like (ajouter ou retirer)
function toggleLike() {
    if (!currentPhotoId) {
        alert('Erreur: Aucune photo sélectionnée.');
        return;
    }

    fetch('api/likes.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            photo_id: currentPhotoId
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Erreur: ' + data.error);
            return;
        }

        // Mettre à jour le modal
        const modalLikeBtn = document.getElementById('modal-like-btn');
        const modalLikeCount = document.getElementById('modal-like-count');
        const likeIcon = modalLikeBtn.querySelector('.like-icon');

        modalLikeCount.textContent = data.like_count;

        if (data.has_liked) {
            likeIcon.textContent = '❤️';
            modalLikeBtn.classList.add('liked');
        } else {
            likeIcon.textContent = '🤍';
            modalLikeBtn.classList.remove('liked');
        }

        // Mettre à jour le compteur sur la miniature
        updateLikeCountOnThumbnail(currentPhotoId, data.like_count);
    })
    .catch(error => {
        console.error('Erreur lors du toggle du like:', error);
        alert('Erreur lors du like.');
    });
}

// Mettre à jour le compteur de likes sur la miniature
function updateLikeCountOnThumbnail(photoId, likeCount) {
    const photoItem = document.querySelector(`.photo-item[data-id="${photoId}"]`);
    if (!photoItem) return;

    let likeElement = photoItem.querySelector('.photo-like-count');

    if (!likeElement) {
        // Créer l'élément s'il n'existe pas
        likeElement = document.createElement('div');
        likeElement.className = 'photo-like-count';
        likeElement.dataset.photoId = photoId;

        const stats = photoItem.querySelector('.photo-stats');
        if (stats) {
            stats.insertBefore(likeElement, stats.firstChild);
        }
    }

    if (likeCount === 0) {
        likeElement.style.display = 'none';
    } else {
        likeElement.style.display = 'flex';
        likeElement.innerHTML = `<span class="like-icon">🤍</span> <span class="like-number">${likeCount}</span>`;
    }
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
