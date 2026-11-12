# Tablet setup status (2026-11-12, updated)

Device: **Lenovo TB-8505X** (`HGR2YTWY`) running **LineageOS 18.1 / Android 11**
(`18.1-20240121-UNOFFICIAL-arm64_bvS`, PHH GSI, arm64_bvS). Managed over USB ADB
(no WiFi required for this setup).

## Installed apps (verified)

| App | Package | Version/build | Purpose |
|---|---|---|---|
| F-Droid | `org.fdroid.fdroid` | 1023052 | Open-source app store |
| SimpleSSHD | `org.galexander.sshd` | 27 | SSH/SCP server on tablet (port 2222) |
| ConnectBot | `org.connectbot` | 11101000 | SSH client |
| MGit | `com.manichord.mgit` | 240 | Git client |
| Markor | `net.gsantner.markor` | 164 | Markdown editor (vault-compatible) |
| KDE Connect | `org.kde.kdeconnect_tp` | 1.37.2 | Ubuntu integration |
| Obsidian | `md.obsidian` | 1.15.1 | Notes/vault |
| Firefox (Fennec) | `org.mozilla.fennec_fdroid` | 1590120 | Browser |
| LocalSend | `org.localsend.localsend_app` | 1.18.2 (arm64) | LAN file transfer |
| Syncthing-Fork | `com.github.catfriend1.syncthingfork` | 2.1.7.0 | Continuous sync |
| Termux | `com.termux` | 0.118.3 (arm64, GitHub) | Terminal, sshd, git, rsync |
| Pixel Player | `com.theveloper.pixelplay` | 0.7.5-beta (arm64) | Music player |
| Telegram (FOSS) | `org.telegram.messenger.beta` | 10.14.3 (TF-BETA) | Messaging |

APKs staged on tablet at `/sdcard/Download/apks/tablet_apps/` (14 files) and
cached locally in `tablet/apps/` (gitignored) / host `tablet_apps/`.

> Telegram-FOSS (`org.telegram.messenger.beta`) was installed because
> `telegram.org` was not reachable from the setup environment; it is a
> FOSS-compatible Telegram client. Replace with official Telegram if preferred
> once you have connectivity.

## Obsidian vault linked to GitHub repo

- Repo: **https://github.com/rezasharifi82/Information-Theory-Notes.git**
- Cloned/pushed to tablet at: `/sdcard/Documents/Information-Theory-Notes/`
  (includes `.git` with `origin` pointing to the GitHub repo).
- Open in **Obsidian**: vault/folder → `Documents/Information-Theory-Notes`.
  Markor can also edit the same Markdown files.
- **Git sync on tablet:** use **MGit** (installed) or **Termux** (`pkg install git`)
  to pull/commit/push. For in-app Obsidian Git plugin, enable community plugins
  in Obsidian and install "Obsidian Git" when network is available.
- Host clone: `/home/mreza/Desktop/TB8505X/Information-Theory-Notes`.

## Communication & services

- **Root ADB (active):** host watcher `~/.config/systemd/user/tb-adb-root.service`
  enabled & active. `adb shell id` → `uid=0(root)`. One-shot: `scripts/tb_adb_root.sh`.
- **SSH to tablet:** SimpleSSHD (open → set password → START), then
  `adb forward tcp:2222 tcp:2222 && ssh -p 2222 <user>@localhost`.
- **SSH from tablet:** ConnectBot; Ubuntu `sshd` inactive by default.
- **Termux SSH:** `pkg update && pkg install openssh git rsync && sshd` (port 8022)
  — `adb forward tcp:8022 tcp:8022`.
- **KDE Connect:** pair with `kdeconnect` on Ubuntu over LAN.
- **Syncthing-Fork / LocalSend:** installed for file sync/transfer.
- **Git:** MGit + Termux git. Docs snapshot at `/sdcard/Documents/TB8505X-notes/`.

## Boot animation

Custom animation `assets/bootanimation.zip` (gold bat emblem, "LINEAGEOS 18.1 /
TB-8505X · akita_row_call", 800×1280, 30f) copied to `/product/media/bootanimation.zip`
(and overlay paths) on 2026-11-12. `/system/media` is read-only on this GSI;
**reboot to verify**. If not picked up, inject into system image or use a Magisk overlay.

## Notes

- All installs done over USB ADB without WiFi. WiFi is enabled but not joined.
- For Telegram official app, install `org.telegram.messenger` when desired.
- Repos pushed: `TB8505X-lineage-os` and `TB8505X-ubuntutouch` on GitHub.
