# TB-8505X — LineageOS 18.1 (Android 11) verified GSI install

Lenovo Tab M8 HD LTE **TB-8505X** (`akita_row_call`), MediaTek MT6761/MT8766B.

This repository is the **working LineageOS install** for the tablet: stock
Android 10 vendor, a stock Android 10 boot image with a GSI-friendly fstab, the
AndyYan LineageOS 18.1 `arm64_bvS` GSI, and root ADB via the GSI's `phh-su`.

The Ubuntu Touch port that preceded this lives in the separate
[`TB8505X-ubuntutouch`](../TB8505X-ubuntutouch) repository.

---

## Verified state (2026-11-12)

| Item | Result |
|---|---|
| OS | LineageOS 18.1 / Android 11 / `userdebug` |
| Build | `18.1-20240121-UNOFFICIAL-arm64_bvS` |
| Vendor | stock Android 10 / SDK 29 / `TB-8505X_USR_S301129_230914…` |
| System | GSI on `mmcblk0p37`, system-as-root |
| Display | 800×1280, panel fully working |
| Power | sleep/wake verified |
| Touch/keys | `fts_ts`, `mtk-tpd`, `mtk-kpd` |
| WiFi / BT | scan works / Bluetooth ON |
| Audio | `mt-snd-card`, AW87519 L/R, playback tested |
| Cameras | 2 devices exposed; Camera2 opens |
| Sensors | accelerometer, light, proximity, step counter |
| Root | `phh-su` → `uid=0`; adbd root via helper/service |
| Data | ~24 GB free, FBE encrypted |

Full test matrix, screenshots and evidence:
[`docs/LINEAGE_18.1_VERIFIED_INSTALL.md`](docs/LINEAGE_18.1_VERIFIED_INSTALL.md).

---

## Repository layout

```
docs/
  INDEX_LINEAGE.md                        index of this install
  LINEAGE_18.1_VERIFIED_INSTALL.md        root cause, images, verification, rollback
  WHY_LINEAGE_WORKS_UT_DOESNT.md          layer-by-layer comparison with Ubuntu Touch
  POSTINSTALL_ROOT_AND_NOTIFICATION_SHADE.md
  TABLET_COMMUNICATION.md                 SSH/git/Obsidian/file-sync setup
  lineage_verification/                   live screenshots
images/
  boot/boot_patched.img                   stock kernel + patched fstab (tracked)
  boot/vbmeta_disabled.img                AVB flags 0x3 (tracked)
  boot/build/                             kernel/ramdisk/dtb intermediates (ignored)
  gsi/                                    GSI download (ignored, use the script)
scripts/
  precheck_flash.sh                       validate everything, write nothing
  flash_verified.sh                       precheck + flash + wipe + reboot
  precheck_images.py                      image-level checks
  download_gsi.sh                         fetch/verify the LineageOS GSI
  tb_adb_root.sh / tb_adb_root_watch.sh   root adbd
  tb-adb-root.service                     systemd user unit for the watcher
  tb_shade.sh                             notification shade over ADB
magisk/tb-adb-root/                       optional Magisk module (not installed)
```

`backups` is a local symlink to `/home/mreza/Desktop/TB8505X/backups` and is
git-ignored. The stock vendor/boot/dtbo/vbmeta backups are **private device
data** and are not committed.

---

## Prerequisites

- Linux host with `adb`/`fastboot` (platform-tools), `python3`, `e2fsck`,
  `debugfs`, `cpio`, `gzip`, `xz`, and `simg2img`.
- Unlocked `akita_row_call` bootloader.
- The stock backups:
  - `backups/brom_full_20261110_210125/vendor.bin`
  - `backups/brom_pre_unlock/boot.bin`, `dtbo.bin`, `vbmeta.bin`
  - full BROM dump for disaster recovery.
- The GSI in `images/gsi/` (see below).

---

## Images

| Partition | Image | Notes |
|---|---|---|
| vendor | `backups/brom_full_20261110_210125/vendor.bin` | stock Android 10, ext4, 838,860,800 B |
| vbmeta | `images/boot/vbmeta_disabled.img` | AVB0, flags `0x00000003` |
| boot | `images/boot/boot_patched.img` | stock kernel/DTB + fstab without AVB/forced FBE |
| dtbo | `backups/brom_pre_unlock/dtbo.bin` | stock X dtbo |
| system | `images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img` | 1.85 GB sparse ext4 |

Tracked hashes:

```text
sha256  f2356fd525cbc71e476253bd29c957b35f685c0acafb99cf2228c777ce553246  images/boot/boot_patched.img
sha256  669023be75f5a17299c7564f3e4a700ebfc50b0a3acad68c7b4ae1a79a5dc0d5  images/boot/vbmeta_disabled.img
sha1    f7ad2f8938818f4866dfbd2f9b718a99a55266a7  images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img.xz
sha1    5807df9ebacb69f034d24c6b3082ecd5d4d327f0  images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img
```

The GSI is too large for git and is ignored. Fetch it with:

```sh
./scripts/download_gsi.sh
```

The stock boot/vendor/dtbo backups are not in git; keep the private backup
directory next to this repository and make the `backups` symlink (or set
`TB8505X_ROOT` and place the files under that root).

---

## Flash

The tablet must be in **bootloader fastboot** (`0e8d:201c`,
`product=akita_row_call`, unlocked, not fastbootd).

```sh
./scripts/precheck_flash.sh          # must PASS, writes nothing
./scripts/flash_verified.sh --yes    # flash + fastboot -w + reboot
```

The flasher runs, in order:

```
vbmeta → vendor → boot → dtbo → system → fastboot -w → reboot
```

It aborts on the first failure, logs to `logs/flash_<timestamp>.log`, and waits
for adb. First boot takes about 100–160 seconds.

The precheck verifies:

- fastboot product/unlock/partition sizes and battery
- vendor ext4, `build.prop`, required directories, `e2fsck`
- boot header v2, kernel gzip/ARM64, ramdisk cpio/init/fstab, MTK DTB
- `fstab` has no `avb`/`forcefdeorfbe`
- vbmeta `AVB0` + flags `0x3`
- GSI `.xz` SHA1, sparse header/chunks, expansion against the real 4 GB
  partition, `simg2img`, ext4 `e2fsck`, `/system/build.prop`, `/system/bin/init`
- dtbo magic/size/hash

---

## Root, SSH and communication

```sh
./scripts/tb_adb_root.sh
adb shell id                 # uid=0(root)
```

For automatic root adbd, install the user service:

```sh
mkdir -p ~/.config/systemd/user
cp scripts/tb-adb-root.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now tb-adb-root.service
```

SSH, git, Obsidian and file-sync setup:
[`docs/TABLET_COMMUNICATION.md`](docs/TABLET_COMMUNICATION.md).

`adb root` itself is blocked by this Lineage build (“ADB Root access is
disabled by system setting”); the helper uses `phh-su` and restarts adbd.

Magisk is **not installed**. The current `phh-su` root plus the watcher is
sufficient; `magisk/tb-adb-root/` is an optional module for people who install
Magisk anyway.

---

## Notification shade

On the tablet: **tap the clock/status bar once** to open the shade; a swipe
start should be inside the status bar (y ≈ 20–40), not on the bezel.

From the host:

```sh
./scripts/tb_shade.sh open
./scripts/tb_shade.sh close
```

Auto-rotate and “Allow Home screen rotation” are enabled.

---

## Why LineageOS works and Ubuntu Touch did not

Short version: Lineage reuses the **stock bootloader/kernel/vendor display
stack**. Ubuntu Touch replaced the whole OS, so the custom kernel had to replay
the MediaTek panel power sequence (`is_lcm_inited` skipped `disp_lcm_init`), and
the separately erased `/vendor` was fatal for Android/GSI but not for Lomiri.

Full analysis: [`docs/WHY_LINEAGE_WORKS_UT_DOESNT.md`](docs/WHY_LINEAGE_WORKS_UT_DOESNT.md).

---

## Rollback

| Need | Image |
|---|---|
| Stock boot / dtbo / vbmeta | `backups/brom_pre_unlock/boot.bin`, `dtbo.bin`, `vbmeta.bin` |
| Stock vendor | `backups/brom_full_20261110_210125/vendor.bin` |
| Full BROM dump | `backups/brom_full_20261110_210125/` |
| Last Ubuntu Touch boot | `../build_lcmfix/boot_lcm.img` |

Do not flash TWRP on this model; use fastboot only. Do not flash an
`akita_row_wifi` (TB-8505F) boot image on this LTE device.

---

## Credits

LineageOS GSI by AndyYan / PHH Treble; UBports and the redstar-team port for the
Ubuntu Touch work and this device's kernel sources. The stock vendor/boot/dtbo
images are from the device owner's own BROM backup.

## License

MIT (same as the Ubuntu Touch port repository).
