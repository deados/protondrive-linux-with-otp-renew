#!/usr/bin/env bash
set -e

# ============================================================
#  setup-proton-mount.sh — Version modifiée pour EndeavourOS
#  Basé sur : https://github.com/dadtronics/protondrive-linux
#  Modifications :
#    - Pacman au lieu de apt-get (Arch/EndeavourOS)
#    - Génération automatique du code TOTP via oathtool
#    - ExecStartPre dans le service systemd
#    - Sécurisation du secret TOTP (fichier séparé, chmod 600)
# ============================================================

# Couleurs pour le terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
error()   { echo -e "${RED}[ERREUR]${NC} $1"; }

# Ne pas exécuter en tant que root
if [[ "$EUID" -eq 0 ]]; then
    error "Ne pas exécuter ce script en tant que root."
    exit 1
fi

# Détecter sudo
SUDO="sudo"

# ------------------------------------------------------------
# 0. Vérifier qu'on est bien sur Arch/EndeavourOS
# ------------------------------------------------------------
if ! command -v pacman &> /dev/null; then
    warn "pacman non détecté. Ce script est conçu pour Arch Linux / EndeavourOS."
    warn "Certaines étapes d'installation pourraient échouer sur d'autres distributions."
    read -p "Continuer quand même ? (y/N) " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
fi

# ------------------------------------------------------------
# 1. Installer rclone (>= 1.64.0) si nécessaire
# ------------------------------------------------------------
info "Vérification de rclone..."

if ! command -v rclone >/dev/null 2>&1; then
    info "rclone non trouvé — installation via pacman..."
    $SUDO pacman -S --noconfirm rclone
else
    RCLONE_VER=$(rclone --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [[ "$(printf '%s\n' "1.64.0" "$RCLONE_VER" | sort -V | head -n1)" != "1.64.0" ]]; then
        warn "rclone $RCLONE_VER détecté — version < 1.64.0 requise."
        info "Mise à jour de rclone via pacman..."
        $SUDO pacman -Syu --noconfirm rclone
    else
        success "rclone $RCLONE_VER détecté — OK."
    fi
fi

# ------------------------------------------------------------
# 2. Installer fuse3 (requis pour le montage FUSE)
# ------------------------------------------------------------
info "Vérification de fuse3..."
if ! pacman -Q fuse3 &> /dev/null; then
    info "Installation de fuse3..."
    $SUDO pacman -S --noconfirm fuse3
else
    success "fuse3 déjà installé."
fi

# ------------------------------------------------------------
# 3. Ajouter l'utilisateur au groupe fuse si nécessaire
# ------------------------------------------------------------
if ! groups "$USER" | grep -qw fuse; then
    info "Ajout de $USER au groupe 'fuse'..."
    $SUDO usermod -aG fuse "$USER"
    FUSE_ADDED=1
else
    success "Utilisateur déjà dans le groupe 'fuse'."
fi

# ------------------------------------------------------------
# 4. Créer le point de montage
# ------------------------------------------------------------
MOUNT_POINT="${HOME}/ProtonDrive"
mkdir -p "$MOUNT_POINT"
success "Point de montage : $MOUNT_POINT"

# ------------------------------------------------------------
# 5. Vérifier/Configurer le remote rclone Proton Drive
# ------------------------------------------------------------
if ! rclone listremotes 2>/dev/null | grep -q "^proton:$"; then
    warn "Aucun remote 'proton:' trouvé dans rclone."
    info "Lancement de la configuration interactive rclone..."
    info "Vous aurez besoin de :"
    info "  - Votre nom d'utilisateur Proton"
    info "  - Votre mot de passe Proton"
    info "  - Un code 2FA valide (généré maintenant depuis votre app)"
    echo ""
    rclone config
else
    success "Remote 'proton:' déjà configuré."
fi

# ------------------------------------------------------------
# 6. Installer oathtool pour la génération TOTP
# ------------------------------------------------------------
info "Vérification de oathtool..."
if ! command -v oathtool &> /dev/null; then
    info "Installation de oathtool (paquet oath-toolkit)..."
    $SUDO pacman -S --noconfirm oath-toolkit
else
    success "oathtool déjà installé."
fi

# ------------------------------------------------------------
# 7. Configurer la clé secrète TOTP
# ------------------------------------------------------------
TOTP_SECRET_FILE="${HOME}/.config/proton-totp.secret"
TOTP_SCRIPT="${HOME}/.config/rclone/gen-totp.sh"
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
LOG_DIR="${HOME}/.cache/rclone"

mkdir -p "${HOME}/.config/rclone"
mkdir -p "$LOG_DIR"

if [[ -f "$TOTP_SECRET_FILE" ]]; then
    success "Clé TOTP déjà configurée."
    read -p "Voulez-vous la remplacer ? (y/N) " REPLACE_TOTP
    if [[ "$REPLACE_TOTP" != "y" && "$REPLACE_TOTP" != "Y" ]]; then
        info "Conservation de la clé TOTP existante."
    fi
else
    REPLACE_TOTP="y"
fi

if [[ "$REPLACE_TOTP" == "y" || "$REPLACE_TOTP" == "Y" ]]; then
    echo ""
    info "Récupération de la clé secrète TOTP :"
    info "  1. Connectez-vous sur https://account.proton.me"
    info "  2. Settings → Account → Two-factor authentication"
    info "  3. Si déjà activée, cliquez sur 'View secret key' ou 'Show secret'"
    info "  4. Copiez la chaîne (ex: JBSWY3DPEHPK3PXP)"
    echo ""
    read -p "Collez votre clé secrète TOTP : " TOTP_SECRET

    if [[ -z "$TOTP_SECRET" ]]; then
        error "Clé TOTP vide — abandon."
        exit 1
    fi

    echo "$TOTP_SECRET" > "$TOTP_SECRET_FILE"
    chmod 600 "$TOTP_SECRET_FILE"
    success "Clé TOTP sauvegardée dans $TOTP_SECRET_FILE"

    # Test immédiat
    TEST_CODE=$(oathtool --totp --base32 "$TOTP_SECRET" 2>/dev/null)
    if [[ -z "$TEST_CODE" ]]; then
        error "Échec de génération du code TOTP. Vérifiez votre clé secrète."
        exit 1
    else
        success "Test TOTP réussi — code généré : $TEST_CODE"
    fi
fi

# ------------------------------------------------------------
# 8. Créer le script de génération TOTP
#    Ce script sera appelé par systemd avant chaque montage
# ------------------------------------------------------------
info "Création du script de génération TOTP..."

# Note : on utilise EOF sans quotes pour permettre l'expansion des variables
cat > "$TOTP_SCRIPT" <<EOF
#!/bin/bash
# Généré par setup-proton-mount.sh
# Ce script génère un code TOTP et l'injecte dans rclone.conf
# Il est appelé par systemd via ExecStartPre avant chaque montage

set -e

SECRET_FILE="${TOTP_SECRET_FILE}"
RCLONE_CONF="${RCLONE_CONF}"

# Charger la clé secrète
if [[ ! -f "\$SECRET_FILE" ]]; then
    echo "[gen-totp] ERREUR: Fichier secret introuvable: \$SECRET_FILE" >&2
    exit 1
fi

SECRET=\$(cat "\$SECRET_FILE" | tr -d '[:space:]')

# Générer le code TOTP
CODE=\$(oathtool --totp --base32 "\$SECRET" 2>/dev/null)

if [[ -z "\$CODE" ]]; then
    echo "[gen-totp] ERREUR: Impossible de générer le code TOTP" >&2
    exit 1
fi

# Injecter le code dans rclone.conf
# Cas 1 : La ligne 2fa existe déjà → remplacer
if grep -q "^2fa = " "\$RCLONE_CONF" 2>/dev/null; then
    sed -i "s/^2fa = .*/2fa = \$CODE/" "\$RCLONE_CONF"
else
    # Cas 2 : La ligne n'existe pas → ajouter à la section [proton]
    # On l'ajoute après la dernière ligne de config du remote proton
    sed -i "/^\\[proton\\]/a 2fa = \$CODE" "\$RCLONE_CONF"
fi

echo "[gen-totp] Code TOTP généré et injecté (\$CODE)"

# Aussi exporter via variable d'environnement (au cas où rclone l'utilise)
export RCLONE_CONFIG_PROTON_2FA="\$CODE"
EOF

chmod 700 "$TOTP_SCRIPT"
success "Script TOTP créé : $TOTP_SCRIPT"

# ------------------------------------------------------------
# 9. Écrire le service systemd utilisateur
# ------------------------------------------------------------
SYSTEMD_DIR="${HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"

info "Création du service systemd..."

cat > "${SYSTEMD_DIR}/rclone-proton.mount.service" <<EOF
[Unit]
Description=Mount Proton Drive via rclone (FUSE)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
# Générer le code TOTP juste avant le montage
ExecStartPre=${TOTP_SCRIPT}
# Monter Proton Drive
ExecStart=/usr/bin/rclone mount proton: ${MOUNT_POINT} \\
    --allow-other \\
    --vfs-cache-mode full \\
    --vfs-cache-max-size 5G \\
    --vfs-cache-max-age 5m \\
    --log-file ${LOG_DIR}/proton-mount.log \\
    --log-level INFO
ExecStop=/bin/fusermount -u ${MOUNT_POINT}
Restart=on-failure
RestartSec=5
KillMode=none
LimitNOFILE=1048576
LimitMEMLOCK=infinity

[Install]
WantedBy=default.target
EOF

success "Service systemd créé : ${SYSTEMD_DIR}/rclone-proton.mount.service"

# ------------------------------------------------------------
# 10. Activer et démarrer le service
# ------------------------------------------------------------
info "Activation du service systemd..."
systemctl --user daemon-reload
systemctl --user enable --now rclone-proton.mount.service

# ------------------------------------------------------------
# 11. Instructions finales
# ------------------------------------------------------------
echo ""
success "Installation terminée !"
echo ""

if [[ "$FUSE_ADDED" == "1" ]]; then
    warn "Vous avez été ajouté au groupe 'fuse'."
    warn "Déconnectez-vous et reconnectez-vous pour que cela prenne effet."
    echo ""
fi

echo -e "${CYAN}Commandes utiles :${NC}"
echo "  Statut    : systemctl --user status rclone-proton.mount.service"
echo "  Redémarrer : systemctl --user restart rclone-proton.mount.service"
echo "  Logs      : journalctl --user -u rclone-proton.mount.service -f"
echo "  Logs rclone : tail -f ${LOG_DIR}/proton-mount.log"
echo "  Vérifier mount : ls ${MOUNT_POINT}"
echo ""
echo -e "${CYAN}Fichiers créés :${NC}"
echo "  Service systemd : ${SYSTEMD_DIR}/rclone-proton.mount.service"
echo "  Script TOTP      : ${TOTP_SCRIPT}"
echo "  Secret TOTP     : ${TOTP_SECRET_FILE} (chmod 600)"
echo "  Config rclone   : ${RCLONE_CONF}"
echo ""
echo -e "${CYAN}Désinstallation :${NC}"
echo "  systemctl --user disable --now rclone-proton.mount.service"
echo "  rm ${SYSTEMD_DIR}/rclone-proton.mount.service"
echo "  rm ${TOTP_SCRIPT} ${TOTP_SECRET_FILE}"
echo "  systemctl --user daemon-reload"
echo ""
