#!/usr/bin/env bash

# ============================================================
#  uninstall-proton-mount.sh
#  Désinstallation propre du montage Proton Drive via rclone
#  Compagnon de setup-proton-mount.sh (version modifiée)
# ============================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
error()   { echo -e "${RED}[ERREUR]${NC} $1"; }

# Ne pas exécuter en tant que root
if [[ "$EUID" -eq 0 ]]; then
    error "Ne pas exécuter ce script en tant que root."
    exit 1
fi

# Chemins (identiques au script d'installation)
SERVICE_NAME="rclone-proton.mount.service"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"
TOTP_SCRIPT="${HOME}/.config/rclone/gen-totp.sh"
TOTP_SECRET="${HOME}/.config/proton-totp.secret"
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
MOUNT_POINT="${HOME}/ProtonDrive"
LOG_DIR="${HOME}/.cache/rclone"
LOG_FILE="${LOG_DIR}/proton-mount.log"

# ------------------------------------------------------------
# Récapitulatif de ce qui sera supprimé
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Désinstallation de Proton Drive Mount ===${NC}"
echo ""
echo "Ce script va :"
echo "  1. Arrêter et désactiver le service systemd"
echo "  2. Démonter Proton Drive si toujours monté"
echo "  3. Supprimer le service systemd"
echo "  4. Supprimer le script de génération TOTP"
echo "  5. Supprimer le fichier secret TOTP"
echo "  6. Nettoyer le code 2FA de rclone.conf"
echo "  7. Supprimer les logs rclone"
echo "  8. (Optionnel) Supprimer le point de montage"
echo "  9. (Optionnel) Supprimer le remote rclone 'proton:'"
echo " 10.(Optionnel) Retirer l'utilisateur du groupe 'fuse'"
echo ""
warn "Certaines actions sont irréversibles."
read -p "Continuer ? (y/N) " CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { echo "Abandon."; exit 0; }
echo ""

# ------------------------------------------------------------
# 1. Arrêter et désactiver le service systemd
# ------------------------------------------------------------
info "Arrêt et désactivation du service..."
if systemctl --user is-active "$SERVICE_NAME" &>/dev/null; then
    systemctl --user stop "$SERVICE_NAME"
    success "Service arrêté."
else
    info "Service déjà arrêté."
fi

if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl --user disable "$SERVICE_NAME"
    success "Service désactivé."
else
    info "Service déjà désactivé."
fi

# ------------------------------------------------------------
# 2. Démonter Proton Drive si toujours monté
# ------------------------------------------------------------
info "Vérification du point de montage..."
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    warn "$MOUNT_POINT est toujours monté — démontage..."
    fusermount -u "$MOUNT_POINT" 2>/dev/null || \
        fusermount3 -u "$MOUNT_POINT" 2>/dev/null || \
        sudo umount "$MOUNT_POINT" 2>/dev/null

    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        error "Impossible de démonter $MOUNT_POINT."
        warn "Essayez manuellement : fusermount -u $MOUNT_POINT"
    else
        success "Proton Drive démonté."
    fi
else
    info "Proton Drive n'est pas monté."
fi

# ------------------------------------------------------------
# 3. Supprimer le service systemd
# ------------------------------------------------------------
info "Suppression du service systemd..."
if [[ -f "$SERVICE_FILE" ]]; then
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    success "Service supprimé : $SERVICE_FILE"
else
    info "Service déjà supprimé."
fi

# ------------------------------------------------------------
# 4. Supprimer le script de génération TOTP
# ------------------------------------------------------------
info "Suppression du script TOTP..."
if [[ -f "$TOTP_SCRIPT" ]]; then
    rm -f "$TOTP_SCRIPT"
    success "Script TOTP supprimé : $TOTP_SCRIPT"
else
    info "Script TOTP déjà supprimé."
fi

# ------------------------------------------------------------
# 5. Supprimer le fichier secret TOTP
# ------------------------------------------------------------
info "Suppression du fichier secret TOTP..."
if [[ -f "$TOTP_SECRET" ]]; then
    # Nettoyage sécurisé (overwrite avant suppression)
    shred -u "$TOTP_SECRET" 2>/dev/null || rm -f "$TOTP_SECRET"
    success "Fichier secret TOTP supprimé : $TOTP_SECRET"
else
    info "Fichier secret TOTP déjà supprimé."
fi

# ------------------------------------------------------------
# 6. Nettoyer le code 2FA de rclone.conf
# ------------------------------------------------------------
info "Nettoyage de rclone.conf..."
if [[ -f "$RCLONE_CONF" ]]; then
    # Supprimer la ligne 2fa = XXXXXX du remote proton
    if grep -q "^2fa = " "$RCLONE_CONF" 2>/dev/null; then
        sed -i '/^2fa = /d' "$RCLONE_CONF"
        success "Code 2FA retiré de rclone.conf."
    else
        info "Aucune ligne 2fa trouvée dans rclone.conf."
    fi

    # Supprimer aussi otp_secret_key si présent
    if grep -q "^otp_secret_key = " "$RCLONE_CONF" 2>/dev/null; then
        sed -i '/^otp_secret_key = /d' "$RCLONE_CONF"
        success "Clé otp_secret_key retirée de rclone.conf."
    fi
else
    info "rclone.conf introuvable — rien à nettoyer."
fi

# ------------------------------------------------------------
# 7. Supprimer les logs rclone
# ------------------------------------------------------------
info "Suppression des logs rclone..."
if [[ -f "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
    success "Log supprimé : $LOG_FILE"
else
    info "Pas de log à supprimer."
fi

# Demander pour le dossier de cache complet
if [[ -d "$LOG_DIR" ]]; then
    read -p "Supprimer tout le dossier de cache rclone ($LOG_DIR) ? (y/N) " DEL_CACHE
    if [[ "$DEL_CACHE" == "y" || "$DEL_CACHE" == "Y" ]]; then
        rm -rf "$LOG_DIR"
        success "Dossier de cache supprimé : $LOG_DIR"
    else
        info "Dossier de cache conservé."
    fi
fi

# ------------------------------------------------------------
# 8. (Optionnel) Supprimer le point de montage
# ------------------------------------------------------------
echo ""
if [[ -d "$MOUNT_POINT" ]]; then
    read -p "Supprimer le point de montage $MOUNT_POINT ? (y/N) " DEL_MOUNT
    if [[ "$DEL_MOUNT" == "y" || "$DEL_MOUNT" == "Y" ]]; then
        rmdir "$MOUNT_POINT" 2>/dev/null
        if [[ -d "$MOUNT_POINT" ]]; then
            warn "Le dossier n'est pas vide — contenu conservé."
            warn "Supprimez-le manuellement si besoin : rm -rf $MOUNT_POINT"
        else
            success "Point de montage supprimé : $MOUNT_POINT"
        fi
    else
        info "Point de montage conservé : $MOUNT_POINT"
    fi
fi

# ------------------------------------------------------------
# 9. (Optionnel) Supprimer le remote rclone 'proton:'
# ------------------------------------------------------------
echo ""
if rclone listremotes 2>/dev/null | grep -q "^proton:$"; then
    warn "Le remote 'proton:' existe toujours dans rclone."
    read -p "Supprimer le remote 'proton:' de rclone ? (y/N) " DEL_REMOTE
    if [[ "$DEL_REMOTE" == "y" || "$DEL_REMOTE" == "Y" ]]; then
        rclone config delete proton
        success "Remote 'proton:' supprimé de rclone."
    else
        info "Remote 'proton:' conservé."
    fi
fi

# ------------------------------------------------------------
# 10. (Optionnel) Retirer l'utilisateur du groupe fuse
# ------------------------------------------------------------
echo ""
if groups "$USER" | grep -qw fuse; then
    read -p "Retirer $USER du groupe 'fuse' ? (y/N) " DEL_FUSE
    if [[ "$DEL_FUSE" == "y" || "$DEL_FUSE" == "Y" ]]; then
        sudo gpasswd -d "$USER" fuse
        success "Utilisateur retiré du groupe 'fuse'."
        warn "Déconnectez-vous/reconnectez-vous pour que cela prenne effet."
    else
        info "Utilisateur conservé dans le groupe 'fuse'."
    fi
fi

# ------------------------------------------------------------
# Résumé final
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}=== Résumé de la désinstallation ===${NC}"
echo ""
echo -e "Service systemd   : $([ -f "$SERVICE_FILE" ] && echo '${RED}Encore présent${NC}' || echo '${GREEN}Supprimé${NC}')"
echo -e "Script TOTP        : $([ -f "$TOTP_SCRIPT" ] && echo '${RED}Encore présent${NC}' || echo '${GREEN}Supprimé${NC}')"
echo -e "Secret TOTP       : $([ -f "$TOTP_SECRET" ] && echo '${RED}Encore présent${NC}' || echo '${GREEN}Supprimé${NC}')"
echo -e "Remote rclone      : $(rclone listremotes 2>/dev/null | grep -q '^proton:$' && echo '${YELLOW}Conservé${NC}' || echo '${GREEN}Supprimé${NC}')"
echo -e "Point de montage   : $([ -d "$MOUNT_POINT" ] && echo '${YELLOW}Conservé${NC}' || echo '${GREEN}Supprimé${NC}')"
echo -e "Logs              : $([ -f "$LOG_FILE" ] && echo '${RED}Encore présent${NC}' || echo '${GREEN}Supprimé${NC}')"
echo ""

# Vérifier qu'il ne reste aucun processus rclone
if pgrep -x rclone &>/dev/null; then
    warn "Des processus rclone tournent encore :"
    pgrep -ax rclone
    echo "  Tuez-les avec : pkill -x rclone"
else
    success "Aucun processus rclone restant."
fi

echo ""
success "Désinstallation terminée."
echo ""
