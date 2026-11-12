# Tablet setup status (2026-11-12)

Device: **Lenovo TB-8505X** (`HGR2YTWY`) running **LineageOS 18.1 / Android 11**
(`18.1-20240121-UNOFFICIAL-arm64_bvS`, PHH GSI, arm64_bvS). Connected via USB ADB.

## Installed apps (verified)

| App | Package | Version | Purpose |
|---|---|---|---|
| F-Droid | `org.fdroid.fdroid` | 1.23.5 (1023052) | Open-source app store |
| SimpleSSHD | `org.galexander.sshd` | 27 | SSH/SCP server on tablet (port 2222) |
| ConnectBot | `org.connectbot` | 1.9.13 (11101000) | SSH client |
| MGit | `com.manichord.mgit` | 1.7.2 (240) | Git client |
| Markor | `net.gsantner.markor` | 2.15.1 (164) | Markdown/text editor (Obsidian-compatible vault editing) |
| KDE Connect | `org.kde.kdeconnect_tp` | 1.37.2 (13702) | Ubuntu integration (clipboard/files/notifications) |

APKs staged on tablet: `/sdcard/Download/apks/tablet_apps/` and in repo at
`tablet/apps/` (gitignored). Host cache: `/home/mreza/Desktop/TB8505X/tablet_apps/`.

## Requested but not auto-installed (install from F-Droid / official source)

Network restrictions in the setup environment prevented reliable downloads of
some APKs. **F-Droid is installed** — open it (with internet/WiFi) and install:

| App | Suggested source | Package |
|---|---|---|
| Firefox (Fennec) | F-Droid | `org.mozilla.fennec_fdroid` |
| LocalSend | F-Droid | `org.localsend.localsend_app` |
| Syncthing-Fork | F-Droid | `com.github.catfriend1.syncthingandroid` |
| Termux | F-Droid (official repo recommended) | `com.termux` |
| Pixel Player | GitHub/F-Droid if available | (verify package on device) |
| Telegram | https://telegram.org/android or F-Droid repo | `org.telegram.messenger` |
| Obsidian | https://obsidian.md/download (official APK) | `md.obsidian` |

> Termux F-Droid APK download attempted earlier failed to install
> (`INSTALL_PARSE_FAILED_NOT_APK`); install Termux from the F-Droid app or
> official Termux builds on-device.

## Communication & services configured

- **Root ADB:** `phh-su` available; host watcher service installed/enabled on
  Ubuntu (`~/.config/systemd/user/tb-adb-root.service`, active).
  ```sh
  adb shell id   # uid=0(root) via watcher
  scripts/tb_adb_root.sh
  ```
- **SSH (tablet server):** SimpleSSHD installed. Open app → set password → START,
  then `adb forward tcp:2222 tcp:2222 && ssh -p 2222 <user>@localhost`.
- **SSH (tablet client):** ConnectBot installed for connecting to Ubuntu host
  when on same network (Ubuntu `sshd` was inactive at setup).
- **Git:** MGit installed; Markor for editing; Termux recommended for full CLI
  once installed.
- **KDE Connect:** installed on tablet; pair with `kdeconnect` on Ubuntu over LAN.
- **Files:** ADB push/pull over USB works now. Docs/notes copied to
  `/sdcard/Documents/TB8505X-notes/`.
- **Obsidian linkage:** vault folder created at `/sdcard/Documents/ObsidianVault/`
  and repo docs staged at `/sdcard/Documents/TB8505X-notes/`. See
  `docs/OBSIDIAN_REPO_LINKAGE.md`. Obsidian app not installed (manual APK needed);
  Markor can edit the same Markdown vault now.

## Boot animation

Custom boot animation generated at `assets/bootanimation.zip` (gold bat emblem,
"LINEAGEOS 18.1 / TB-8505X · akita_row_call", 800×1280, 30 frames).
Installed to `/product/media/bootanimation.zip` (and copied to overlay/cache paths
via `adb remount`) on 2026-11-12. `/system/media` is read-only on this GSI;
effect depends on bootanim search order — reboot to verify. If not picked up,
the zip can be injected into the system image or applied via a Magisk overlay.

## Quick commands

```sh
# root adbd
scripts/tb_adb_root.sh

# notification shade
scripts/tb_shade.sh open

# SSH to tablet (after starting SimpleSSHD)
adb forward tcp:2222 tcp:2222
ssh -p 2222 localhost

# mirror screen (if scrcpy installed)
scrcpy
```

## Notes

- WiFi is enabled but no network was joined during setup; install remaining apps
  from F-Droid once connected.
- Ubuntu host `sshd` is inactive; enable only if you want tablet→host SSH.
- All changes committed and pushed to `TB8505X-lineage-os` and
  `TB8505X-ubuntutouch` (2026-11-12).
