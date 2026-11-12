# TB-8505X — Verified LineageOS 18.1 install

Date: 2026-11-12 18:55 (+0330)
Device: Lenovo Tab M8 HD LTE (`TB-8505X` / `akita_row_call`), MT6761/MT8766B
Result: **booted, display working, hardware verified**

---

## 1. Root cause of the "Lenovo logo → fastboot" loop

Two independent defects had to be fixed:

1. **`/vendor` was erased.** `recovery/brom.sh wipe` erases
   `userdata,cache,metadata,system,vendor,product` (see `recovery/brom.sh:44`).
   With an empty vendor partition, Android/GSI cannot bring up the vendor HALs;
   the kernel/init fails and LK falls back to fastboot. The stock Android 10
   vendor was still available in `backups/brom_full_20261110_210125/vendor.bin`
   (valid ext4, `TB-8505X_USR_S301129_2309141226_V9.56_BMP_ROW`).
2. **The stock boot ramdisk's first-stage fstab still forced AVB/verity and
   forced FBE** for the old stock system. A GSI cannot satisfy those.
   `fstab.mt6761` was patched:
   - `/system` and `/vendor`: removed `avb=vbmeta` / `avb`
   - `/data`: `forcefdeorfbe=...` → `encryptable=...`

Everything else (kernel, GSI, userdata) was already fine.

## 2. Exact image set that booted

| Partition | Image | SHA / identity |
|---|---|---|
| vendor | `backups/brom_full_20261110_210125/vendor.bin` | sha256 `2c293322…3d92f` |
| vbmeta | `images/boot/vbmeta_disabled.img` | AVB0, flags `00000003` |
| boot | `images/boot/boot_patched.img` | stock kernel + fstab patch + stock dtb |
| dtbo | `backups/brom_pre_unlock/dtbo.bin` | sha256 `684d5bba…a5f3` |
| system | `images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img` | xz sha1 `f7ad2f89…66a7` |

## 3. Verification results (live device)

| Area | Result | Evidence |
|---|---|---|
| Android version | **PASS** | Android 11 / SDK 30 / `userdebug` |
| ROM | **PASS** | `18.1-20240121-UNOFFICIAL-arm64_bvS` (Phh-Treble) |
| Boot state | **PASS** | `sys.boot_completed=1`, `verifiedbootstate=orange`, `flash.locked=0` |
| Display | **PASS** | 800×1280, density 240; setup wizard, launcher, Settings all render (screenshots `screen.png`, `home.png`, `wake.png`) |
| Panel | **PASS** | no black screen; content visible at full brightness |
| Power key | **PASS** | `input keyevent 26`: `mWakefulness=Awake → Dozing / Display OFF → Awake / ON` |
| Touch | **PASS (driver)** | `fts_ts` (FocalTech) and `mtk-tpd` input devices present |
| Keys | **PASS (driver)** | `mtk-kpd` input device |
| WiFi | **PASS** | scan returned neighbor APs (Sonic-5G/2.4G, others) |
| Bluetooth | **PASS** | `enabled: true`, `state: ON` |
| Cameras | **PARTIAL** | 2 camera devices exposed by `media.camera`; Camera2 app opens. Preview screenshot was dark (lens/side not validated) |
| Audio | **PASS** | ALSA `mt-snd-card`; AW87519 L/R on I2C `6-0058`/`6-005b`; `tinyplay` played a 1 kHz WAV and the speaker amp turned on (`aw87519_left_audio_speaker`, `hw_on`) |
| Sensors | **PASS** | accelerometer, light (EM30918), proximity, step detector/counter, wake gestures |
| Root | **PASS** | `/system/bin/phh-su -c id` → `uid=0(root)` |
| Storage | **PASS** | data 23 GB free; Settings reports 24.41 GB free; vendor 775 MB; cache 232 MB |
| Battery | **PASS** | 87 %, status charging, health good, 27 °C |
| Encryption | **PASS** | `ro.crypto.state=encrypted`, `/data` on dm-0 |
| Vendor | **PASS** | mounted on `/vendor` (mmcblk0p36), Android 10 / SDK 29 / VNDK 29 |
| System | **PASS** | mounted on `/` (mmcblk0p37), GSI ext4, read-only |

Not tested / needs the owner:
- 4G/LTE calls and mobile data (no SIM test)
- WiFi association (no credentials given) — scan radio works
- Bluetooth pairing/audio
- Physical touch (driver present; `input tap` works)
- Camera preview/photo quality

## 4. Reproducible scripts

- `precheck_flash.sh` — validates all images, partitions, sparse structure,
  ext4 filesystems, boot header/fstab, and the fastboot device. **PASS, 0 errors.**
- `flash_verified.sh --yes` — reruns the precheck, then flashes in order:
  `vbmeta → vendor → boot → dtbo → system → fastboot -w → reboot`, aborting on
  the first failure. Logs to `logs/flash_<timestamp>.log`.
- `lineage_install.sh` — download helper; its `flash` action now delegates to
  `flash_verified.sh` (so it restores vendor and the patched boot).

The monitor bug in `flash_verified.sh` (a `grep` returning 1 under `set -e`)
was fixed; the first boot was verified manually.

## 5. Rollback

| Need | Image |
|---|---|
| Stock boot | `backups/brom_pre_unlock/boot.bin` |
| Stock dtbo | `backups/brom_pre_unlock/dtbo.bin` |
| Stock vbmeta | `backups/brom_pre_unlock/vbmeta.bin` |
| Stock vendor | `backups/brom_full_20261110_210125/vendor.bin` |
| Full BROM dump | `backups/brom_full_20261110_210125/` |
| Last Ubuntu Touch boot | `build_lcmfix/boot_lcm.img` |

Ubuntu Touch 24.04 was replaced. Its kernel/rootfs work is preserved in the
repo, but the tablet now runs LineageOS 18.1.

## 6. Note on Antigravity

The `agy` session in tmux returns
`FAILED_PRECONDITION (400): User location is not supported for the API use.`
It could not be used; all checks were run locally.
