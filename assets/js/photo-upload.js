/**
 * Gestion de l'upload de photos - Version finale
 */

let selectedFiles = [];

// Ouvrir le modal d'upload
function showUploadModal() {
    document.getElementById('upload-modal').style.display = 'block';
    resetUploadModal();
}

// Fermer le modal d'upload
function closeUploadModal() {
    document.getElementById('upload-modal').style.display = 'none';
    resetUploadModal();
}

// Réinitialiser le modal d'upload
function resetUploadModal() {
    selectedFiles = [];
    document.getElementById('upload-prompt').style.display = 'block';
    document.getElementById('upload-preview').style.display = 'none';
    document.getElementById('upload-progress').style.display = 'none';
    document.getElementById('upload-results').style.display = 'none';
    document.getElementById('preview-images').innerHTML = '';
    document.getElementById('photo-input').value = '';
}

// Configurer le drag & drop et le sélecteur de fichiers
const uploadArea = document.getElementById('upload-area');
const photoInput = document.getElementById('photo-input');

// Clic sur la zone d'upload
uploadArea.addEventListener('click', (e) => {
    if (e.target.id === 'upload-area' || e.target.closest('#upload-prompt')) {
        photoInput.click();
    }
});

// Sélection de fichiers via l'input
photoInput.addEventListener('change', (e) => {
    handleFiles(e.target.files);
});

// Drag & drop
uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.style.borderColor = 'var(--accent-purple)';
    uploadArea.style.backgroundColor = 'var(--bg-secondary)';
});

uploadArea.addEventListener('dragleave', (e) => {
    e.preventDefault();
    uploadArea.style.borderColor = 'var(--border-color)';
    uploadArea.style.backgroundColor = 'var(--bg-card)';
});

uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.style.borderColor = 'var(--border-color)';
    uploadArea.style.backgroundColor = 'var(--bg-card)';

    const files = e.dataTransfer.files;
    handleFiles(files);
});

// Gérer les fichiers sélectionnés
function handleFiles(files) {
    const validFiles = [];
    const maxSize = 20 * 1024 * 1024; // 20 MB
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

    for (let file of files) {
        // Vérifier le type
        if (!allowedTypes.includes(file.type)) {
            alert(`${file.name}: Type de fichier non autorisé. Utilisez JPG, PNG, GIF ou WEBP.`);
            continue;
        }

        // Vérifier la taille
        if (file.size > maxSize) {
            alert(`${file.name}: Fichier trop volumineux (max 20 MB)`);
            continue;
        }

        validFiles.push(file);
    }

    if (validFiles.length === 0) {
        return;
    }

    selectedFiles = validFiles;
    showPreview();
}

// Afficher la prévisualisation
function showPreview() {
    document.getElementById('upload-prompt').style.display = 'none';
    document.getElementById('upload-preview').style.display = 'block';

    const previewContainer = document.getElementById('preview-images');
    previewContainer.innerHTML = '';

    document.getElementById('photo-count').textContent = selectedFiles.length;

    selectedFiles.forEach((file, index) => {
        const reader = new FileReader();

        reader.onload = (e) => {
            const previewItem = document.createElement('div');
            previewItem.style.cssText = 'position: relative; border: 3px solid var(--border-color); overflow: hidden;';

            previewItem.innerHTML = `
                <img src="${e.target.result}" style="width: 100%; height: 150px; object-fit: cover; display: block;">
                <div style="padding: 8px; background-color: var(--bg-secondary); font-size: 11px; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">
                    ${file.name}
                </div>
                <button onclick="removeFile(${index})"
                        style="position: absolute; top: 5px; right: 5px; background-color: var(--accent-pink); color: var(--text-primary); border: 2px solid var(--border-color); width: 30px; height: 30px; cursor: pointer; font-weight: 700; font-size: 16px; padding: 0; line-height: 1;">
                    ×
                </button>
            `;

            previewContainer.appendChild(previewItem);
        };

        reader.readAsDataURL(file);
    });
}

// Supprimer un fichier de la sélection
function removeFile(index) {
    selectedFiles.splice(index, 1);

    if (selectedFiles.length === 0) {
        resetUploadModal();
    } else {
        showPreview();
    }
}

// Uploader les photos - VERSION FINALE FONCTIONNELLE
async function uploadPhotos() {
    if (selectedFiles.length === 0) {
        return;
    }

    console.log('🚀 DÉBUT UPLOAD de', selectedFiles.length, 'fichier(s)');

    // Afficher la barre de progression
    document.getElementById('upload-preview').style.display = 'none';
    document.getElementById('upload-progress').style.display = 'block';

    const progressBar = document.getElementById('progress-bar');
    const progressText = document.getElementById('progress-text');
    const uploadStatus = document.getElementById('upload-status');

    const results = {
        success: [],
        errors: []
    };

    // Uploader chaque fichier SÉQUENTIELLEMENT
    for (let i = 0; i < selectedFiles.length; i++) {
        const file = selectedFiles[i];
        const formData = new FormData();
        formData.append('photo', file);

        // Mettre à jour le statut IMMÉDIATEMENT
        const statusMsg = `Upload de ${file.name}... (${i + 1}/${selectedFiles.length})`;
        uploadStatus.textContent = statusMsg;
        console.log(`📤 ${i + 1}/${selectedFiles.length}:`, file.name, `(${(file.size / 1024 / 1024).toFixed(2)} MB)`);

        try {
            console.log('  ➤ Envoi du fichier...');

            const response = await fetch('upload.php', {
                method: 'POST',
                body: formData,
                credentials: 'same-origin' // IMPORTANT: envoie les cookies de session
            });

            console.log('  ← Réponse HTTP:', response.status, response.statusText);

            // Vérifier si la réponse est OK
            if (!response.ok) {
                const errorText = await response.text();
                console.error('  ✗ Erreur serveur:', errorText.substring(0, 200));

                results.errors.push({
                    filename: file.name,
                    error: `Erreur serveur (${response.status}): ${response.statusText}`
                });

                // Continuer avec le prochain fichier
                continue;
            }

            // Parser la réponse JSON
            let data;
            try {
                const responseText = await response.text();
                console.log('  ← Réponse brute:', responseText.substring(0, 150) + '...');
                data = JSON.parse(responseText);
            } catch (jsonError) {
                console.error('  ✗ Erreur parsing JSON:', jsonError);
                console.error('  ✗ Réponse reçue:', responseText);

                results.errors.push({
                    filename: file.name,
                    error: 'Réponse serveur invalide'
                });

                continue;
            }

            // Vérifier le résultat
            if (data.success) {
                console.log('  ✓ Upload réussi!');
                results.success.push({ filename: file.name, data: data.photo });
            } else {
                console.error('  ✗ Upload échoué:', data.error);
                results.errors.push({ filename: file.name, error: data.error });
            }

        } catch (error) {
            console.error('  ✗ Exception:', error);
            results.errors.push({
                filename: file.name,
                error: `Erreur réseau: ${error.message}`
            });
        }

        // METTRE À JOUR LA BARRE DE PROGRESSION
        const progress = Math.round(((i + 1) / selectedFiles.length) * 100);
        progressBar.style.width = progress + '%';
        progressText.textContent = progress + '%';
        console.log(`  📊 Progression: ${progress}%`);
    }

    console.log('🏁 UPLOAD TERMINÉ');
    console.log('  ✓ Succès:', results.success.length);
    console.log('  ✗ Erreurs:', results.errors.length);

    // Afficher les résultats
    showResults(results);
}

// Afficher les résultats de l'upload
function showResults(results) {
    document.getElementById('upload-progress').style.display = 'none';
    document.getElementById('upload-results').style.display = 'block';

    const resultsContent = document.getElementById('results-content');
    let html = '';

    if (results.success.length > 0) {
        html += `
            <div style="background-color: rgba(139, 69, 139, 0.2); border: 3px solid var(--accent-purple); padding: 20px; margin-bottom: 15px;">
                <p style="font-weight: 700; color: var(--accent-purple); margin-bottom: 10px;">
                    ✓ ${results.success.length} photo(s) uploadée(s) avec succès
                </p>
                <ul style="font-size: 13px; color: var(--text-secondary); margin-left: 20px;">
        `;

        results.success.forEach(item => {
            html += `<li style="margin: 5px 0;">${item.filename}</li>`;
        });

        html += `
                </ul>
            </div>
        `;
    }

    if (results.errors.length > 0) {
        html += `
            <div style="background-color: rgba(219, 112, 147, 0.2); border: 3px solid var(--accent-pink); padding: 20px;">
                <p style="font-weight: 700; color: var(--accent-pink); margin-bottom: 10px;">
                    ✗ ${results.errors.length} erreur(s)
                </p>
                <ul style="font-size: 13px; color: var(--text-secondary); margin-left: 20px;">
        `;

        results.errors.forEach(item => {
            html += `<li style="margin: 5px 0;"><strong>${item.filename}:</strong> ${item.error}</li>`;
        });

        html += `
                </ul>
            </div>
        `;
    }

    resultsContent.innerHTML = html;
}

// Fermer les modals en cliquant en dehors
window.addEventListener('click', (e) => {
    const uploadModal = document.getElementById('upload-modal');
    if (e.target === uploadModal) {
        closeUploadModal();
    }
});

console.log('✓ Photo upload script loaded');
