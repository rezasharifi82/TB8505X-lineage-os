# LineageOS install — index

Current state as of **2026-11-12**: the tablet boots LineageOS 18.1 (Android 11,
`arm64_bvS`), display and hardware verified. Ubuntu Touch is not installed; its
sources and OTA live in the separate
[`TB8505X-ubuntutouch`](../TB8505X-ubuntutouch) repository.

## Read in this order

1. [LINEAGE_18.1_VERIFIED_INSTALL.md](LINEAGE_18.1_VERIFIED_INSTALL.md) —
   root cause, exact images, live verification matrix, rollback.
2. [WHY_LINEAGE_WORKS_UT_DOESNT.md](WHY_LINEAGE_WORKS_UT_DOESNT.md) —
   layer-by-layer comparison of the two OS stacks.
3. [POSTINSTALL_ROOT_AND_NOTIFICATION_SHADE.md](POSTINSTALL_ROOT_AND_NOTIFICATION_SHADE.md) —
   root adbd, automatic root watcher, notification-shade behaviour.
4. [TABLET_COMMUNICATION.md](TABLET_COMMUNICATION.md) — SSH, git, Obsidian,
   file sync and app installation.
5. [lineage_verification/](lineage_verification/) — screenshots from the live
   device.

## Flashing tools

All tools live in this repository under `scripts/`:

| Tool | Purpose |
|---|---|
| `scripts/precheck_flash.sh` | validates every image, partition size, ext4 filesystem, boot header/fstab and the fastboot device before writing |
| `scripts/flash_verified.sh --yes` | precheck, then flash `vbmeta → vendor → boot → dtbo → system → fastboot -w → reboot` |
| `scripts/precheck_images.py` | image-level checks used by the precheck |
| `scripts/download_gsi.sh` | fetch/verify the LineageOS GSI into `images/gsi/` |
| `scripts/tb_adb_root.sh` | switch adbd to root through `phh-su` |
| `scripts/tb_adb_root_watch.sh` | keep adbd root while the tablet is connected |
| `scripts/tb-adb-root.service` | systemd **user** unit for the watcher |
| `scripts/tb_shade.sh` | open/close the notification shade over ADB |

`TB8505X_ROOT` defaults to this repository root. The `backups` symlink points
to the private BROM dumps; the GSI is downloaded separately because it is too
large for git.

## Root

`adb shell phh-su -c id` → `uid=0`. For root adbd:

```sh
./scripts/tb_adb_root.sh
```

or install the user service (recommended):

```sh
mkdir -p ~/.config/systemd/user
cp scripts/tb-adb-root.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now tb-adb-root.service
```

## Root service

The installed host unit runs `scripts/tb_adb_root_watch.sh`; it detects the
tablet and runs:

```sh
phh-su -c 'setprop service.adb.root 1; setprop ctl.restart adbd'
```

`adb root` itself is blocked by this Lineage build even with Developer options
enabled; the helper bypasses that.

## Magisk

Optional only. `magisk/tb-adb-root/` is a ready module for people who install
Magisk; it is **not** installed. The current `phh-su` root plus the host watcher
already gives unrestricted root adbd without touching the boot image.

## Safe rollback

| Need | Image |
|---|---|
| Stock boot / dtbo / vbmeta | `backups/brom_pre_unlock/boot.bin`, `dtbo.bin`, `vbmeta.bin` |
| Stock vendor | `backups/brom_full_20261110_210125/vendor.bin` |
| Full BROM dump | `backups/brom_full_20261110_210125/` |
| Last Ubuntu Touch boot | `../build_lcmfix/boot_lcm.img` |

Do not flash TWRP on this model.
