# Why LineageOS 18.1 works and Ubuntu Touch did not

**Device:** Lenovo Tab M8 HD LTE (`TB-8505X`, `akita_row_call`), MT6761/MT8766B
**Dates:** Ubuntu Touch work 2026-11-05…12; LineageOS install 2026-11-12
**Short answer:** LineageOS reuses the device's **original bootloader, kernel and
vendor display stack**. Ubuntu Touch replaces the whole OS, so the panel power
sequence had to be reimplemented in a downstream kernel and a second, unrelated
failure (an erased `/vendor`) became fatal. It is not that Lineage is "better";
it is simply much closer to what the tablet shipped with.

---

## 1. Layer-by-layer difference

| Layer | LineageOS 18.1 (works) | Ubuntu Touch 24.04 (did not) |
|---|---|---|
| **Boot image** | Stock Android 10 boot image from `backups/brom_pre_unlock/boot.bin`: stock 4.9.190 kernel, stock 99,298-byte MTK DTB, stock first-stage ramdisk. Only the fstab was patched. | Custom Halium boot (`build_lcmfix/boot_lcm.img` / `focal_build/out/boot.img`) with a self-built 4.9.190 kernel and a Halium initramfs. |
| **Ramdisk** | Stock Android first-stage init + `fstab.mt6761` with `avb`/`forcefdeorfbe` removed. | Halium initramfs. The CI Noble used a 5.4 MB **dynparts** ramdisk built for the TB-8505F; the working one is the 4.1 MB **discrete-partition** ramdisk. |
| **Kernel display init** | Stock MediaTek `mtkfb`/DSI driver, the same code the bootloader was designed for. LK powers the panel; the stock kernel keeps that state and the stock vendor display HAL drives it. | Same downstream driver family, but `primary_display_init()` sees `is_lcm_inited=1` from LK and **skips `disp_lcm_init()`**. Linux then reprograms pinctrl/DSI; the +5.4 V/−5.4 V bias rails (GPIO 167/168) and reset (GPIO 45) stay low, so the panel is unpowered. |
| **/vendor** | Stock Android 10 vendor (`vendor.bin`) mounted on `/vendor`. Provides the display/audio/sensor/camera HALs and firmware. | `recovery/brom.sh wipe` erases `userdata,cache,metadata,system,**vendor**,product`. UT's Lomiri/Mir UI can still render into `/dev/fb0` without vendor, so the UI came up (dark) while Android/GSI cannot boot without it. |
| **Userspace graphics** | SurfaceFlinger + the vendor gralloc/HWC path. Correct panel timing, backlight and power. | Mir/Lomiri compositing into `/dev/fb0`. The framebuffer contained a complete purple desktop (96.7 % non-zero bytes) but the panel was physically dark. |
| **Rootfs** | LineageOS 18.1 `arm64_bvS` GSI (Android 11, system-as-root) on the 4 GB system partition. | Ubuntu 24.04 rootfs + Halium 10 GSI + `akita_row_call` device overlay on the system partition. |
| **Device variant** | GSI is generic and uses the **stock X vendor/kernel**, so the X-specific hardware is handled by Lenovo's own blobs. | The CI artifacts were named `akita_row_wifi` (TB-8505F, Wi-Fi-only), with X overlays added afterwards. Telephony and display needed extra work. |
| **Power/sleep** | Stock Android power HAL + LineageOS framework. Power key works (verified `Awake → Dozing/Display OFF → Awake/ON`). | `repowerd`/`logind` had to be reconfigured; the earliest build had a non-working power button, and the display wake depended on a manual fb0 blank cycle. |
| **Result** | Boots, display works, wifi/BT/audio/sensors/root verified. | Userspace rendered, but the panel stayed dark; the kernel fix was never fully validated and the missing vendor made a GSI-style boot impossible. |

---

## 2. The display bug in one diagram

```
Ubuntu Touch boot:
  LK powers the panel, sets is_lcm_inited=1
        |
        v
  Linux mtkfb probe -> primary_display_init(is_lcm_inited=1)
        |
        +-- skips disp_lcm_init()       <-- panel power-on/init table never replayed
        |
        +-- DSI reset in ddp_dsi_power_on()
        |
        v
  Mir draws the desktop into /dev/fb0     <-- fb0 was 96.7% non-zero (purple UI)
        |
        v
  panel bias rails GPIO167/168 and reset GPIO45 = LOW
        |
        v
  backlight glow, no image ("black screen")

LineageOS boot:
  stock boot + stock vendor + stock dtbo
        |
        v
  stock 4.9 kernel's display path and vendor HAL stay in the state LK left them
        |
        v
  panel powered and streaming; SurfaceFlinger draws normally
```

Evidence from the previous sessions:

- `MORNING_STATUS.md` §2.1: `/dev/fb0` = 800×1280, 32 bpp, 96.7 % non-zero,
  stable purple UI. The compositor was never the problem.
- `MORNING_STATUS.md` §2.3: `dsi0` had 4 interrupts since boot while `rdma0`
  had 543,073 — the display controller was reading frames but DSI was not
  streaming them to the panel.
- `MORNING_STATUS.md` §2.4: `echo resume > /sys/kernel/debug/mtkfb` was a
  no-op because `primary_display_resume()` early-exited when
  `pgc->state == DISP_ALIVE`.
- `MORNING_STATUS.md` §2.6: the LCM pinctrl group claimed the touch reset
  GPIO 172, which the touch driver already owned; the state apply failed and
  rolled back the bias rails.
- `reports/task3_display.md` §1.1–1.5: the cold-boot `is_lcm_inited` branch,
  the fstab/pinctrl analysis, and the NULL dereference in `sm5109.c`.
- `ROOT_CAUSE_AND_24_04_PLAN.md` §3: the full BUG-1 write-up and the
  `fb0/blank 4 → 0` workaround.

---

## 3. The second, independent failure: `/vendor` was erased

`recovery/brom.sh` line 44:

```sh
DATA_PARTS="userdata,cache,metadata,system,vendor,product"
```

The wipe step erases those partitions and deliberately preserves the
bootloader/NV partitions. It was run several times during the UT experiments.
The full BROM backup still contains a valid stock vendor
(`backups/brom_full_20261110_210125/vendor.bin`, ext4, Android 10 /
`TB-8505X_USR_S301129_2309141226_V9.56_BMP_ROW`).

This explains the seemingly contradictory symptoms:

- **Ubuntu Touch** could reach Lomiri because its UI is a normal Linux
  userspace rendering to fbdev; it does not need `/vendor` to draw.
- **Android/GSI** cannot bring up the vendor HALs without `/vendor`; init fails
  and LK falls back to fastboot (the "Lenovo logo → fastboot" loop).

Restoring vendor was the step that turned the GSI from "logo → fastboot" into
a working boot.

---

## 4. Exact diff that made LineageOS boot

Files (all under `/home/mreza/Desktop/TB8505X`):

| Partition | Image | Why |
|---|---|---|
| vendor | `backups/brom_full_20261110_210125/vendor.bin` | replace the erased stock vendor |
| vbmeta | `images/boot/vbmeta_disabled.img` | AVB flags `0x00000003` (hashtree + verification off) |
| boot | `images/boot/boot_patched.img` | stock kernel/DTB + fstab without `avb` and `forcefdeorfbe` |
| dtbo | `backups/brom_pre_unlock/dtbo.bin` | stock X dtbo |
| system | `images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img` | LineageOS 18.1 GSI |

Then `fastboot -w` and reboot. The verified precheck/flasher is in
`precheck_flash.sh` / `flash_verified.sh` and in this repo under
`scripts/`.

---

## 5. What Ubuntu Touch would still need

Ubuntu Touch is not impossible, but it needs the following, all at once:

1. **Cold-boot panel init.** Force `disp_lcm_init()` at boot, or run the
   delayed `lcm_reinit` hook after userspace is up and trigger the video path.
   The Nov 12 kernel (`arch/arm64/boot/Image`, SHA `5b2df7d4…`) already adds a
   `lcm_reinit=<seconds>` hook; it was never proven on a visible panel because
   the boot stalled earlier.
2. **Vendor partition present.** Halium's Android container and the audio/
   sensor/camera HALs need it. Restore the stock vendor.
3. **Discrete-partition ramdisk.** Keep the 4.1 MB ramdisk; do not use the
   TB-8505F dynparts ramdisk.
4. **A 24.04 rootfs built for `akita_row_call`**, not the `akita_row_wifi` CI
   image with overlays. The F build lacks LTE/telephony and some X quirks.
5. **Power/sleep fixes** (`repowerd`, `logind`, display-wake service) and the
   audio amp routing.
6. **Debug access** (ADB `mtp_adb` and/or RNDIS SSH) so failures are visible
   without a working panel.

The UT kernel sources, patches, OTA and boot image remain in this repo; no
further UT flash was performed after the LineageOS install.

---

## 6. Conclusion

LineageOS worked because it is the **stock Android boot chain plus a generic
system image** — the same kernel, DTB, vendor blobs and display HAL that Lenovo
shipped. Ubuntu Touch was a **full OS replacement** whose custom kernel had to
replay the MediaTek panel power sequence, which the stock kernel had never
needed to do. The display bug, the later erased vendor, and the TB-8505F
dynparts artifacts compounded each other. The tablet is now on the path with
the fewest moving parts: LineageOS 18.1 GSI with stock vendor.
