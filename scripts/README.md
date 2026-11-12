# Scripts

All scripts operate on **this repository root** (`TB8505X_ROOT` defaults to
`<repo>`). The tablet must be in bootloader fastboot for the flashing scripts.

| File | Purpose |
|---|---|
| `precheck_flash.sh` | validates host tools, fastboot device, partition sizes, image hashes, boot header/kernel/ramdisk/dtb, fstab flags, vbmeta flags, GSI sparse structure, vendor/system ext4 and build props. Writes nothing. |
| `flash_verified.sh` | runs the precheck, then flashes `vbmeta → vendor → boot → dtbo → system`, wipes data/cache, reboots and waits for adb. Requires `--yes`. |
| `precheck_images.py` | image-only checks used by `precheck_flash.sh`. |
| `download_gsi.sh` | downloads/verifies the AndyYan LineageOS 18.1 `arm64_bvS` GSI into `images/gsi/`. |
| `tb_adb_root.sh` | switches adbd to root through the GSI's `phh-su`. |
| `tb_adb_root_watch.sh` | keeps adbd root while the tablet is connected. |
| `tb-adb-root.service` | systemd **user** unit for the watcher. |
| `tb_shade.sh` | opens/closes the notification shade over ADB. |

Expected local layout:

```text
backups/brom_full_20261110_210125/vendor.bin   (private, symlink or copy)
backups/brom_pre_unlock/dtbo.bin               (private)
images/boot/boot_patched.img
images/boot/vbmeta_disabled.img
images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img
```

`backups` is a local symlink and is git-ignored. See
`docs/LINEAGE_18.1_VERIFIED_INSTALL.md` for the full procedure and hashes.
