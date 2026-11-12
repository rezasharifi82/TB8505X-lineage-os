# Magisk module: TB-8505X root adbd

Optional. The current LineageOS 18.1 install already has root through
`/system/bin/phh-su`, and the host watcher (`scripts/tb_adb_root_watch.sh`)
turns adbd root automatically. This module is only for people who install
Magisk and want the same behaviour from the device side.

## Install

1. Create a zip with this directory as the module root:

   ```sh
   cd magisk
   zip -r ../tb8505x-adb-root.zip tb-adb-root
   ```

2. Magisk app → Modules → Install from storage → `tb8505x-adb-root.zip`.
3. Reboot. `adb shell id` should report `uid=0`.

The module runs `service.sh` late in boot; it waits for `sys.boot_completed`,
sets `service.adb.root=1`, and restarts `adbd`.

**Warning:** Magisk patches the boot image. Keep
`../images/boot/boot_patched.img` and the stock boot from
`backups/brom_pre_unlock/boot.bin` available before trying it. The current
system works without Magisk.
