# Tablet ↔ Ubuntu communication

Device: **LineageOS 18.1 (PHH GSI, arm64_bvS)** on TB-8505X, connected over USB.
Host: Ubuntu desktop at `/home/mreza/Desktop/TB8505X`. Date: 2026-11-12.

## 1. ADB (primary, works now)

ADB is the most reliable channel because it works over USB without WiFi.

```sh
export ADB=~/tools/platform-tools/adb
$ADB devices -l          # HGR2YTWY, Phh-Treble vanilla
$ADB shell id            # uid=0 when rooted via watcher/helper
```

Root adbd is handled on the host by `scripts/tb_adb_root.sh` or the installed
user service `~/.config/systemd/user/tb-adb-root.service` (see
`docs/POSTINSTALL_ROOT_AND_NOTIFICATION_SHADE.md`).

Useful:

```sh
# file transfer
adb push ./file /sdcard/Download/
adb pull /sdcard/DCIM ./DCIM

# port forward (e.g. tablet SSH on 2222 -> host localhost:2222)
adb forward tcp:2222 tcp:2222

# reverse (tablet can reach host service)
adb reverse tcp:8080 tcp:8080

# screen mirror (if scrcpy installed on host)
scrcpy
```

## 2. SSH

### Option A — SimpleSSHD (server on tablet, recommended over USB)

`org.galexander.sshd` is installed. It runs an SSH server on the tablet
(default port **2222**, password set in the app).

1. Open **SimpleSSHD** on the tablet, set a password, tap **START**.
2. Forward the port over USB:
   ```sh
   adb forward tcp:2222 tcp:2222
   ssh -p 2222 <user-shown-in-app>@localhost
   # or: scp -P 2222 file <user>@localhost:/sdcard/Download/
   ```
3. For key auth, use the app's authorized_keys UI/path shown in-app.

This gives you shell access and `scp`/`sftp` to `/sdcard` without WiFi.

### Option B — ConnectBot (SSH client on tablet)

`org.connectbot` is installed. Use it to SSH **from the tablet to the Ubuntu
host** once both are on the same network (WiFi/hotspot/tether):

```sh
# on Ubuntu, if you want the tablet to log in:
sudo apt install openssh-server
sudo systemctl enable --now ssh
ip -4 addr   # give this IP to ConnectBot
```

> The host's sshd was **inactive** at setup time; enable it only if you want
> inbound SSH from the tablet.

### Option C — Termux (full SSH/git environment on tablet)

Termux was pushed to `/sdcard/Download/apks/` but failed to install from the
downloaded F-Droid APK on this run (`INSTALL_PARSE_FAILED_NOT_APK` / package
mismatch). Install Termux from **F-Droid** on the tablet (recommended) or from
the official Termux GitHub/F-Droid builds, then:

```sh
pkg update
pkg install openssh git rsync
sshd                 # starts on port 8022
passwd               # set termux password
# from host: adb forward tcp:8022 tcp:8022 && ssh -p 8022 localhost
```

Termux gives a proper Linux userspace (git, ssh, python, rsync, etc.).

## 3. Git

- **MGit** (`com.manichord.mgit`) is installed — clone/pull/push repos to
  `/sdcard` via HTTPS/SSH.
- **Markor** (`net.gsantner.markor`) is installed — Markdown/text editor, good
  companion for notes repos.
- With Termux: full `git` CLI.

Suggested workflow for this repo:

```sh
# host -> tablet mirror (fast, over USB)
adb push /home/mreza/Desktop/TB8505X/TB8505X-lineage-os /sdcard/Documents/TB8505X-lineage-os

# or keep a notes/docs clone on tablet via MGit pointing to GitHub
# https://github.com/rezasharifi82/TB8505X-lineage-os.git
```

Current tablet copies created during setup:
- `/sdcard/Documents/TB8505X-notes/` — README and docs snapshot
- `/sdcard/Documents/ObsidianVault/` — empty vault folder

## 4. Obsidian

Obsidian was **not installed automatically** (GitHub/APK download was blocked
by network restrictions in the setup environment). Options:

1. **Install from F-Droid/Play (when online):** not on F-Droid; use the
   official APK from https://obsidian.md/download or GitHub releases
   `obsidianmd/obsidian-releases` and `adb install Obsidian.apk`.
2. **Open-source alternative (installed):** **Markor** edits Markdown vaults
   locally and works well with git-synced folders.
3. **Vault linkage:**
   - On host keep the vault at e.g. `~/ObsidianVault` (or inside a git repo).
   - Sync to tablet: `adb push ~/ObsidianVault /sdcard/Documents/ObsidianVault`
     or use **Syncthing** (see below) for continuous sync.
   - In Obsidian (or Markor), open `/sdcard/Documents/ObsidianVault` as the
     vault. A git-backed vault can be pulled/pushed with MGit/Termux.

## 5. File sync & device integration

| App | Package | Status | Use |
|---|---|---|---|
| F-Droid | `org.fdroid.fdroid` | **installed** | Install/update open-source apps |
| SimpleSSHD | `org.galexander.sshd` | **installed** | SSH server on tablet |
| ConnectBot | `org.connectbot` | **installed** | SSH client |
| MGit | `com.manichord.mgit` | **installed** | Git client |
| Markor | `net.gsantner.markor` | **installed** | Markdown/notes editor |
| Termux | `com.termux` | APK in `/sdcard/Download/apks/` (install from F-Droid) | Terminal, sshd, git, rsync |
| KDE Connect | `org.kde.kdeconnect_tp` | install from F-Droid | Clipboard/files/notifications with Ubuntu |
| Syncthing-Fork | `com.github.catfriend1.syncthingandroid` | install from F-Droid | Continuous folder sync |
| LocalSend | `org.localsend.localsend_app` | install from F-Droid | LAN file transfer |
| Firefox/Fennec | `org.mozilla.fennec_fdroid` | install from F-Droid | Browser |
| Telegram | `org.telegram.messenger` | install from telegram.org/F-Droid repos | Messaging |
| Obsidian | `md.obsidian` | manual APK | Notes/vault |

All downloaded APKs (and any future ones) are in
`/sdcard/Download/apks/tablet_apps/` on the tablet.

### KDE Connect (Ubuntu ↔ tablet)

```sh
# Ubuntu
sudo apt install kdeconnect
# open KDE Connect, pair with tablet on same network
```
Install KDE Connect from F-Droid on the tablet. Features: shared clipboard,
file/URL send, notification sync, media control, remote input.

### Syncthing (continuous sync)

Install **Syncthing-Fork** on tablet and `syncthing` on Ubuntu. Pair devices and
share a folder (e.g. `ObsidianVault` or `TB8505X-notes`) for automatic
bidirectional sync when on the same network.

## 6. USB networking without WiFi

- **ADB file transfer/forward/reverse** works over USB now (no network config).
- **USB tethering (tablet shares mobile data):** Settings → Network & Internet →
  Hotspot & tethering → USB tethering (needs SIM/data).
- **Reverse tethering (host shares internet to tablet):** possible via
  `gnirehtet` or manual `rndis`+iptables on host; useful if tablet has no WiFi
  credentials yet.

## 7. Quick status (2026-11-12)

- Tablet reachable: `adb` over USB, `sys.boot_completed=1`.
- Root adbd: via `phh-su` helper/service.
- `/sdcard` accessible; APKs staged in `/sdcard/Download/apks/`.
- Obsidian/Telegram/Firefox/Syncthing-Fork/KDE Connect/LocalSend not installed
  due to download/network limits; install from F-Droid once the tablet has
  internet (F-Droid is installed).
