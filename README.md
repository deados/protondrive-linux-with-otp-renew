# protondrive-linux-with-otp-renew

[![GitHub license](https://img.shields.io/github/license/dadtronics/protondrive-linux.svg)](https://github.com/dadtronics/protondrive-linux/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/dadtronics/protondrive-linux.svg)](https://github.com/dadtronics/protondrive-linux/stargazers)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-supported-blue.svg)](https://archlinux.org/)
[![EndeavourOS](https://img.shields.io/badge/EndeavourOS-supported-purple.svg)](https://endeavouros.com/)

# 🚀 Présentation
Montage automatique de **Proton Drive** sur **Arch Linux** / **EndeavourOS** utilisant `rclone` et `systemd`, avec **gestion automatique du code 2FA (TOTP)**.

Basé sur le projet original : [dadtronics/protondrive-linux](https://github.com/dadtronics/protondrive-linux)

---

## ✨ Fonctionnalités

- **Gestion 2FA TOTP** : génération automatique des codes via `oathtool`
- **Mount automatique** : démarrage à la connexion utilisateur via `systemd --user`
- **Cache VFS** : mode `full` avec limite configurable (5 Go par défaut)
- **Logging** : logs rclone accessibles dans `~/.cache/rclone/proton-mount.log`
- **Sécurité** : clé secrète TOTP stockée dans un fichier dédié (`chmod 600`)
- **Désinstallation propre** : script inclus avec nettoyage sécurisé (`shred`)

---

## ⚙️ Prérequis

| Composant | Version minimale | Installation |
|-----------|------------------|--------------|
| Arch Linux / EndeavourOS | - | Système hôte |
| rclone | >= 1.64.0 | `sudo pacman -S rclone` |
| fuse3 | - | `sudo pacman -S fuse3` |
| oath-toolkit | - | `sudo pacman -S oath-toolkit` |

Vérifier que tout est en place :
```bash
pacman -Q rclone fuse3 oath-toolkit
```
---
## 📥 Installation

### 1. Cloner ou télécharger les scripts
```bash
cd ~
git clone https://github.com/deados/protondrive-linux-with-otp-renew.git
cd protondrive-linux-with-otp-renew
chmod +x setup-proton-mount.sh uninstall-proton-mount.sh
```

### 2. Lancer l'installation
```bash
./setup-proton-mount.sh
```
Le script va :

1. Installer/vérifier `rclone`, `fuse3`, `oath-toolkit`
2. Ajouter votre utilisateur au groupe `fuse`
3. Configurer `rclone` avec votre compte Proton (si pas déjà fait)
4. Demander votre clé secrète TOTP (une seule fois)
5. Créer le service `systemd` avec génération automatique TOTP
6. Démarrer le montage immédiatement

### 3. Reconnexion si ajout au groupe fuse

Si le script indique que vous avez été ajouté au groupe `fuse`, déconnectez-vous et reconnectez-vous pour que cela prenne effet.

---

## 🔑 Récupération de la clé secrète TOTP

1. Accédez à : https://account.proton.me/u/1/account-password#two-fa
2. Cocher `Authenticator App`
   
   <img width="920" height="703" alt="image" src="https://github.com/user-attachments/assets/76937901-10d7-4083-bd71-87771335fcf8" />
   
4. Cliquer sur `Enter key manually instead`
   
   <img width="589" height="425" alt="image" src="https://github.com/user-attachments/assets/7ae3d98b-47d4-485e-a424-e9bbf6cf7974" />
   
5. Noter la clé secrète "Key", chaîne Base32 (ex: JBSWY3DPEBLW64TMMQ)
   
   <img width="518" height="263" alt="image" src="https://github.com/user-attachments/assets/b7c7ebfe-ad6e-480c-ac26-75f7a4e7976a" />
   
6. Coller la clé dans le script lors de l'installation

> ⚠️ Important : Conservez cette clé secrète. Sans elle, vous ne pourrez pas régénérer de nouveaux codes 2FA.
> 
> **Note :** Cette clé n'est demandée qu'une seule fois. Elle est ensuite stockée de façon sécurisée dans `~/.config/proton-totp.secret`.

---

## 🎮 Utilisation courante

### Vérifier l'état du montage
```bash
systemctl --user status rclone-proton.mount.service
````

### Voir les logs en temps réel
```bash
journalctl --user -u rclone-proton.mount.service -f
# ou
tail -f ~/.cache/rclone/proton-mount.log
```

### Redémarrer le montage
```bash
systemctl --user restart rclone-proton.mount.service
```

### Vérifier que Proton Drive est monté
```bash
ls ~/ProtonDrive
mountpoint ~/ProtonDrive
```

## Démonter/monter manuellement
### Démonter
```bash
systemctl --user stop rclone-proton.mount.service
```
### Remonter
```bash
systemctl --user start rclone-proton.mount.service
```

---

## 🧹 Désinstallation
```bash
./uninstall-proton-mount.sh
```

Le script effectue les actions suivantes (avec confirmation à chaque étape) :

| Action | Détail |
|--------|--------|
| Arrêter le service | `systemctl --user stop` |
| Démonter | `fusermount -u ~/ProtonDrive` |
| Supprimer le service | `~/.config/systemd/user/rclone-proton.mount.service` |
| Supprimer le script TOTP | `~/.config/rclone/gen-totp.sh` |
| Supprimer le secret TOTP | `~/.config/proton-totp.secret` (nettoyage `shred`) |
| Nettoyer rclone.conf | Retrait des lignes `2fa` et `otp_secret_key` |
| Supprimer les logs | `~/.cache/rclone/proton-mount.log` |
| Optionnel | Point de montage, remote rclone, groupe `fuse` |

---

## 📁 Structure des fichiers
protondrive-linux-arch/
├── setup-proton-mount.sh              # Script d'installation
├── uninstall-proton-mount.sh          # Script de désinstallation
├── README.md                          # Documentation
└── LICENSE                            # Licence MIT

~/.config/
├── systemd/user/
│   └── rclone-proton.mount.service    # Service systemd généré
├── rclone/
│   ├── rclone.conf                    # Configuration rclone
│   └── gen-totp.sh                    # Script TOTP (généré)
└── proton-totp.secret                 # Clé TOTP (chmod 600)

~/
├── ProtonDrive/                       # Point de montage FUSE
└── .cache/rclone/
    └── proton-mount.log               # Log rclone

---

## 🐛 Dépannage
### Le montage échoue

```bash
# Vérifier l'état du service
systemctl --user status rclone-proton.mount.service

# Voir les logs détaillés
journalctl --user -u rclone-proton.mount.service -b

# Vérifier les logs rclone
tail -n 50 ~/.cache/rclone/proton-mount.log
```

### Erreur FUSE / permission denied

```bash
# Installer fuse3
sudo pacman -S fuse3

# Ajouter user_allow_other dans /etc/fuse.conf
sudo nano /etc/fuse.conf
# Décommenter : user_allow_other

# Ajouter l'utilisateur au groupe fuse
sudo usermod -aG fuse $USER
# Puis déconnection/reconnection
```

### Code 2FA expiré ou invalide
La clé TOTP n'a pas été configurée correctement :
```bash
# Vérifier que le script TOTP fonctionne
~/.config/rclone/gen-totp.sh

# Régénérer la configuration
./uninstall-proton-mount.sh
./setup-proton-mount.sh
```

### Fichiers vides ou cache corrompu
Le cache VFS peut avoir des problèmes :
```bash
# Démonter
systemctl --user stop rclone-proton.mount.service

# Vider le cache
rm -rf ~/.cache/rclone/*

# Remonter
systemctl --user start rclone-proton.mount.service
```

### Permission denied sur certains fichiers
```bash
# Vérifier les permissions du point de montage
ls -la ~/ProtonDrive

# Ajuster si nécessaire
chown -R $USER:$USER ~/ProtonDrive
```

---

## ⚙️ Paramètres avancés

### Modifier la taille du cache VFS
Éditez le fichier systemd :
```bash
nano ~/.config/systemd/user/rclone-proton.mount.service
```
Changer la valeur :
```bash
--vfs-cache-max-size 5G
```
Vers une valeur plus élevée (ex: 10G, 20G) selon vos besoins.

Puis rechargerez :
```bash
systemctl --user daemon-reload
systemctl --user restart rclone-proton.mount.service
```

### Changer le niveau de log

Dans le même fichier, modifier :
```bash
--log-level INFO
```
Options disponibles : ERROR, NOTICE, INFO, DEBUG

---

## ⚠️ Avertissements légaux
Ce logiciel est fourni "tel quel", sans garantie d'aucune sorte. Nous ne sommes pas responsables de tout dommage résultant de son utilisation.

Important : Ce script utilise l'API non officielle de Proton Drive via rclone. Proton AG ne fournit pas de support officiel pour cette méthode d'accès. Utilisez ce script à vos risques et périls.

---

## 🔗 Liens utiles
| Ressource | URL |
|-----------|-----|
| Documentation rclone Proton Drive | https://rclone.org/protondrive/ |
| Projet original | https://github.com/dadtronics/protondrive-linux |
| Forum rclone | https://forum.rclone.org/ |
| Support Proton | https://proton.me/support |

---

## 👏 Remerciements
- **dadtronics** pour le [script original](https://github.com/dadtronics/protondrive-linux)
- L'équipe **rclone** pour leur outil
- L'équipe **Proton** pour Proton Drive
- La communauté **Arch Linux** / **EndeavourOS**

---

## 📄 Licence

MIT -- voir le fichier [LICENSE](LICENSE).
