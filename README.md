# Mount Proton Drive on Linux using rclone and systemd

This guide automates the process of mounting [Proton Drive](https://proton.me/drive) on a Linux system using [`rclone`](https://rclone.org/) and `systemd`.

Tested on **Arch Linux**, but should work on most Linux distributions with minor adjustments.

---

## 🔧 Features

- Mounts Proton Drive at login via `systemd --user`
- Uses `rclone` with `--vfs-cache-mode writes` for compatibility
- Enables background service with logging
- Adds FUSE support for `--allow-other` mounts

---

## 🚀 Quick Start

### 1. ✅ Install Dependencies

#### Install `fuse3` (required for mounting):
```bash
sudo pacman -S fuse3
````

#### Install `rclone` (must be v1.64.0 or newer)

🔹 **Option 1: Use precompiled binary (recommended)**

```bash
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cd rclone-*-linux-amd64
sudo cp rclone /usr/local/bin/
sudo chmod +x /usr/local/bin/rclone
```

Verify:

```bash
rclone version
# Must be v1.64.0 or higher
```

---

### 2. 🔐 Configure Proton Drive Remote

Run:

```bash
rclone config
```

Follow prompts:

* `n` → New remote
* Name: `proton`
* Type: `protondrive`
* Log in via browser when prompted
* Accept and save

---

### 3. 📜 Run Setup Script

Run the provided script:

```bash
chmod +x setup-proton-mount.sh
./setup-proton-mount.sh
```

The script will:

* Create the mount point: `~/ProtonDrive`
* Write the systemd user service
* Add `user_allow_other` to `/etc/fuse.conf` (if missing)
* Add user to the `fuse` group (if needed)
* Enable and start the mount service

---

### 4. 🔁 Reboot or Log Out/In

If the script added you to the `fuse` group, you must **log out and back in** for the change to take effect.

---

## 🔍 Verify Mount

Check if Proton Drive is mounted:

```bash
ls ~/ProtonDrive
```

Check systemd service:

```bash
systemctl --user status rclone-proton.mount.service
```

---

## 🔁 Remount

If unmounted the Proton Drive can be remounted by:

```bash
systemctl --user restart rclone-proton.mount.service
```

Note the Proton Drive is mounted each time you login automatically.

## 🧼 Uninstall

To remove the installation, use **uninstall-proton-mount.sh**:

```bash
chmod +x uninstall-proton-mount.sh
./uninstall-proton-mount.sh
```
---

## 📁 Files

* `setup-proton-mount.sh` — full setup script
* `~/.config/systemd/user/rclone-proton.mount.service` — systemd unit
* `~/ProtonDrive` — mount location
* `~/.cache/rclone/rclone-proton.log` — log output (optional)

---

## 📎 Requirements

* `rclone >= 1.64.0` with Proton Drive support
* `fuse3`
* A Proton Drive account

---

## 🛟 Commandes utiles :
  Statut    : systemctl --user status rclone-proton.mount.service
  Redémarrer : systemctl --user restart rclone-proton.mount.service
  Logs      : journalctl --user -u rclone-proton.mount.service -f
  Logs rclone : tail -f /home/deados/.cache/rclone/proton-mount.log
  Vérifier mount : ls /home/deados/ProtonDrive

## Fichiers créés :
  Service systemd : /home/deados/.config/systemd/user/rclone-proton.mount.service
  Script TOTP      : /home/deados/.config/rclone/gen-totp.sh
  Secret TOTP     : /home/deados/.config/proton-totp.secret (chmod 600)
  Config rclone   : /home/deados/.config/rclone/rclone.conf

## Désinstallation :
  systemctl --user disable --now rclone-proton.mount.service
  rm /home/deados/.config/systemd/user/rclone-proton.mount.service
  rm /home/deados/.config/rclone/gen-totp.sh /home/deados/.config/proton-totp.secret
  systemctl --user daemon-reload

---

## 📚 References

* [rclone Proton Drive Docs](https://rclone.org/protondrive/)
* [systemd user services](https://wiki.archlinux.org/title/Systemd/User)
