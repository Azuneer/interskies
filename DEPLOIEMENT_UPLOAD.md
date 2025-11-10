# 📸 DÉPLOIEMENT FONCTIONNALITÉ UPLOAD - INTERSKIES

## 🎯 Version finale - Tout-en-un

Ce guide vous permet de déployer la fonctionnalité d'upload de photos en **une seule commande**.

---

## ⚡ Installation rapide (recommandé)

```bash
# 1. Aller dans le répertoire git
cd /chemin/vers/votre/depot/git/interskies

# 2. Récupérer les dernières modifications
git pull origin claude/sky-photo-gallery-mvc-011CUxpBHMfUZMKfa4r32kEv

# 3. Lancer le script de déploiement final
sudo chmod +x setup_upload_final.sh
sudo ./setup_upload_final.sh
```

**C'est tout !** Le script fait automatiquement :
- ✅ Détecte votre installation
- ✅ Copie tous les fichiers au bon endroit
- ✅ Configure les permissions correctement
- ✅ Augmente les limites PHP (20 MB)
- ✅ Vérifie que tout fonctionne

---

## 📋 Ce qui est inclus

### Fichiers copiés automatiquement :
- `upload.php` → Backend d'upload sécurisé
- `assets/js/photo-upload.js` → Interface d'upload
- `admin.php` → Page admin mise à jour

### Fonctionnalités :
- ✨ Upload de photos via navigateur
- 🖱️ Drag & drop
- 📊 Barre de progression fonctionnelle
- 🔒 Sécurité (authentification, validation)
- 📝 Logs détaillés (console navigateur + PHP)
- ✅ Validation (type, taille, format)

### Limites :
- **20 MB** par photo
- **JPG, PNG, GIF, WEBP**
- Upload multiple possible

---

## 🧪 Tester l'upload

1. Allez sur `https://votre-domaine.com/admin.php`
2. Connectez-vous
3. Cliquez sur **"📷 Ajouter des photos"**
4. Appuyez sur **F12** → Onglet **Console**
5. Sélectionnez une photo et cliquez **"Uploader"**

### Ce que vous devez voir dans la console :

```
✓ Photo upload script loaded
🚀 DÉBUT UPLOAD de 1 fichier(s)
📤 1/1: ma-photo.jpg (2.45 MB)
  ➤ Envoi du fichier...
  ← Réponse HTTP: 200 OK
  ← Réponse brute: {"success":true,...
  ✓ Upload réussi!
  📊 Progression: 100%
🏁 UPLOAD TERMINÉ
  ✓ Succès: 1
  ✗ Erreurs: 0
```

---

## 🔍 En cas de problème

### La barre de progression ne bouge pas

**Vérifiez la console F12** - Elle vous dira exactement ce qui ne va pas :

**Erreur: 401 "Non authentifié"**
→ Vous n'êtes pas connecté. Reconnectez-vous sur `/admin.php`

**Erreur: 413 "Request Entity Too Large"**
→ Photo trop grosse OU limites PHP trop basses
→ Le script devrait avoir configuré 20MB automatiquement
→ Relancez: `sudo ./setup_upload_final.sh`

**Erreur: "photos directory not writable"**
→ Problème de permissions
→ Relancez: `sudo ./setup_upload_final.sh`

**Erreur: "Erreur réseau"**
→ Vérifiez les logs nginx: `sudo tail -50 /var/log/nginx/error.log`

### Logs serveur

**Logs upload.php (très détaillés):**
```bash
sudo tail -f /var/log/php8.4-fpm.log
```

Vous devez voir:
```
=== UPLOAD.PHP START ===
User authenticated: admin
File uploaded: photo.jpg (2458640 bytes)
MIME type detected: image/jpeg
Image validated: 3024x4032
Target path: /var/www/interskies.com/photos/photo.jpg
File moved successfully
Photo added to database with ID: 42
=== UPLOAD.PHP SUCCESS ===
```

**Logs nginx:**
```bash
sudo tail -f /var/log/nginx/error.log
```

---

## 🛠️ Scripts disponibles

### `setup_upload_final.sh` ⭐
Le script principal qui fait TOUT automatiquement.

### `diagnostic_upload.sh`
Diagnostic complet de l'installation :
```bash
sudo ./diagnostic_upload.sh
```

### `fix_php_upload_limits.sh`
Augmente manuellement les limites PHP (déjà fait par setup_upload_final.sh) :
```bash
sudo ./fix_php_upload_limits.sh
```

### `change_password.sh`
Change le mot de passe admin :
```bash
sudo ./change_password.sh admin NouveauMotDePasse
```

---

## 🔐 Sécurité

L'upload est sécurisé avec :

✅ **Authentification obligatoire** - Seuls les admins connectés peuvent uploader
✅ **Validation du type MIME** - Pas de faux fichiers
✅ **Vérification getimagesize()** - Vraie validation d'image
✅ **Limite de taille** - 20 MB max
✅ **Extensions autorisées** - JPG, PNG, GIF, WEBP uniquement
✅ **Nom de fichier nettoyé** - Pas d'injection de path
✅ **Permissions restrictives** - 775 sur photos/, propriétaire www-data

---

## 📞 Support

Si après avoir lancé `setup_upload_final.sh` l'upload ne fonctionne toujours pas :

1. **Ouvrez F12 → Console** et tentez un upload
2. **Copiez les messages de la console**
3. **Copiez les logs PHP:**
   ```bash
   sudo tail -100 /var/log/php8.4-fpm.log | grep -A 20 "UPLOAD.PHP"
   ```
4. Envoyez ces informations pour diagnostic

---

## ✨ Fonctionnalités

- [x] Upload de photos via navigateur
- [x] Drag & drop
- [x] Prévisualisation avant upload
- [x] Upload multiple
- [x] Barre de progression
- [x] Gestion des erreurs
- [x] Logs détaillés
- [x] Validation complète
- [x] Sécurité renforcée
- [x] Auto-ajout en base de données
- [x] Génération de noms uniques

---

**Version:** Finale
**Date:** 2025-01-10
**Status:** ✅ Production Ready
