# Tablet setup status (2026-11-12, final)

Device: **Lenovo TB-8505X** (`HGR2YTWY`) running **LineageOS 18.1 / Android 11**
(`18.1-20240121-UNOFFICIAL-arm64_bvS`, PHH GSI, arm64_bvS). Managed over USB ADB
(no WiFi required).

## Installed apps (verified)

| App | Package | Notes |
|---|---|---|
| F-Droid | `org.fdroid.fdroid` | Open-source app store |
| Obsidian | `md.obsidian` | 1.15.1, vault notes |
| Firefox (Fennec) | `org.mozilla.fennec_fdroid` | Browser |
| LocalSend | `org.localsend.localsend_app` | 1.18.2 (arm64) |
| Syncthing-Fork | `com.github.catfriend1.syncthingfork` | 2.1.7.0 |
| Termux | `com.termux` | 0.118.3 (arm64), terminal |
| Pixel Player | `com.theveloper.pixelplay` | 0.7.5-beta (arm64) |
| Telegram (FOSS) | `org.telegram.messenger.beta` | 10.14.3 |
| KDE Connect | `org.kde.kdeconnect_tp` | 1.37.2 |
| Bitwarden | `com.x8bit.bitwarden` | fdroid build 2026.10.1-bwpm |
| NetBird | `io.netbird.client` | v0.6.2 |
| Aurora Store | `com.aurora.store` | 4.8.4 |
| NewPipe | `org.schabi.newpipe` | 0.29.1 |
| Aegis | `com.beemdevelopment.aegis` | 3.4.3 (2FA) |
| Material Files | `me.zhanghai.android.files` | 1.7.5 |

**Removed per request:** Markor, ConnectBot, MGit, SimpleSSHD.

> Telegram-FOSS installed (telegram.org unreachable during setup); replace with
> official Telegram if preferred when online.

## Obsidian ↔ Git (Information-Theory-Notes)

- Repo: **https://github.com/rezasharifi82/Information-Theory-Notes.git**
- On tablet: `/sdcard/Documents/Information-Theory-Notes/` (full clone with
  `.git`, `origin` → GitHub, branch `main`). Open as vault in **Obsidian**.
- Host clone: `/home/mreza/Desktop/TB8505X/Information-Theory-Notes`.
- Git workflow on tablet: **Termux** (see below). When online, use `git pull/push`
  in Termux or install Obsidian Git plugin.

## Termux (apt, storage, git)

- `apt`/`pkg`/`dpkg` binaries present (bootstrap). **Storage access configured:**
  `~/storage/shared` → `/sdcard`, plus `downloads`, `documents`, `pictures`, `dcim`,
  `external-0` symlinks. Permissions granted (`READ/WRITE/MANAGE_EXTERNAL_STORAGE`).
- **Git offline:** git and common dependencies (`libcurl`, `openssl`, `pcre2`,
  `libexpat`, `less`, `libssh2`, `ncurses`, `libiconv`, etc.) were extracted into
  `$PREFIX` and debs staged at `~/pkgs` and `/sdcard/Download/termux_pkgs/` for
  manual/offline use. If `git` is not fully functional in your session (Termux
  packaging/linker specifics), run `pkg install git openssh` once the tablet has
  network — `apt/pkg` are ready.
- Example: `cd ~/storage/shared/Documents/Information-Theory-Notes`

## Communication (ADB-focused)

- **Root ADB:** host watcher `~/.config/systemd/user/tb-adb-root.service` enabled
  & active (`phh-su` → `service.adb.root=1`). `adb shell id` → `uid=0(root)`.
  One-shot: `TB8505X-lineage-os/scripts/tb_adb_root.sh`.
- **ADB is the primary channel:** `adb push/pull`, `adb shell`, port forwarding
  (`adb forward`), reverse (`adb reverse`), `adb install`, screen via `scrcpy`.
  No SimpleSSHD/ConnectBot installed (as requested).
- **KDE Connect**, **Syncthing-Fork**, **LocalSend** installed for LAN sync when
  available. **NetBird** installed for mesh VPN.

## Optimizations & customization applied

- Animations: window/transition/animator scales set to **0.5**.
- Screen timeout **10 min**; adaptive brightness on; stay awake while charging.
- Background process limit reduced; WiFi/BLE scan-always disabled.
- Battery/deviceidle whitelist: Termux, Syncthing-Fork.
- **Wallpaper & lockscreen** set to custom images:
  `/sdcard/Pictures/wallpaper_lineage.png`, `/sdcard/Pictures/lockscreen_lineage.png`
  (copied to `/data/system/users/0/wallpaper{,_lock}`).
- **Boot animation:** custom bat-emblem `assets/bootanimation.zip` installed to
  `/product/media/bootanimation.zip` (+ overlay paths). Reboot to verify on this GSI.

APKs staged on tablet at `/sdcard/Download/apks/tablet_apps/` and cached locally
in `tablet/apps/` (gitignored).
