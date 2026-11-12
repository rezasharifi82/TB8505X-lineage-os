# Post-install: root ADB and the notification shade

**Device state:** LineageOS 18.1 (`18.1-20240121-UNOFFICIAL-arm64_bvS`),
Android 11, stock Android 10 vendor, root via PHH `phh-su`.
Date: 2026-11-12.

---

## 1. Root over ADB

### What works

The GSI is the **`S`** variant, so it ships `/system/bin/phh-su`:

```sh
adb shell phh-su -c id
# uid=0(root) ...
```

To make **adbd itself** run as root:

```sh
adb shell "phh-su -c 'setprop service.adb.root 1; setprop ctl.restart adbd'"
sleep 3
adb shell id
# uid=0(root) ...
```

This was verified on the tablet. `service.adb.root=1` lasts until the next
reboot.

### Why `adb root` fails

LineageOS advertises rooted debugging but the host command still answers:

```
ADB Root access is disabled by system setting - enable in Settings -> System -> Developer options
```

even with:

```sh
adb shell settings put global adb_root_enabled 1
adb shell settings put global development_settings_enabled 1
```

The GSI does define `/system/etc/init/adb_root.rc` and the `adb_root` service
runs, but it does not set `service.adb.root` on boot. The reliable route is the
`phh-su` command above.

### Host helper

`scripts/tb_adb_root.sh` does the whole sequence and prints the resulting
`id`:

```sh
./scripts/tb_adb_root.sh
```

### Automatic root (recommended)

`scripts/tb_adb_root_watch.sh` checks every 10 s and roots adbd whenever
the tablet is connected. Install it as a **systemd user service** (no sudo):

```sh
mkdir -p ~/.config/systemd/user
cp scripts/tb-adb-root.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now tb-adb-root.service
systemctl --user status tb-adb-root.service
```

The unit assumes the repo is at
`~/Desktop/TB8505X/TB8505X-ubuntutouch` and adb at
`~/tools/platform-tools/adb`; edit `ExecStart`/`Environment` if yours differ.

After that, every time the tablet appears:

```
$ adb shell id
uid=0(root) gid=0(root) ...
```

**Installed on this host on 2026-11-12:** the user unit
`~/.config/systemd/user/tb-adb-root.service` is enabled and active, so adbd is
rooted automatically whenever the tablet is connected.

### Magisk

**Magisk is not required and was not installed.** The existing `phh-su` root
already gives full root, and the host watcher removes the need for a boot
script. Magisk patches the boot image, which would put the working display/boot
setup at risk.

If you still want it, a ready Magisk module is in
`magisk/tb-adb-root/` (it sets `service.adb.root=1` after boot). Read its
README and keep `images/boot/boot_patched.img` and the stock boot available
before flashing a Magisk-patched boot.

### Security

Root adbd means the USB host has unrestricted root. Keep USB debugging off when
not using it, and never expose ADB over TCP on an untrusted network.

---

## 2. Notification shade

### Verified behaviour

- `adb shell cmd statusbar expand-notifications` opens the shade.
- **Tapping the status bar / clock once opens the shade** on this build
  (verified with `input tap 400 20`).
- A swipe that starts at the very top bezel may not register; start at
  **y ≈ 20–40 px**, inside the status bar, not on the plastic edge.
- Auto-rotate and "Allow Home screen rotation" were enabled, so if the tablet
  is held in landscape the status bar follows the top of the current
  orientation.

### Permanent workarounds

1. **Tap the status bar/clock** instead of swiping. This is the cleanest
   on-device fix and works with a finger.
2. Open the shade from the PC:

   ```sh
   ./scripts/tb_shade.sh open
   ./scripts/tb_shade.sh close
   ```

3. If the top edge of the digitizer is genuinely insensitive (screen protector
   or bezel), use the tap method; the touch controller itself is fine:

   ```
   /dev/input/event3  fts_ts   ABS_MT_POSITION_X 0…800
                                ABS_MT_POSITION_Y 0…1280
   ```

   `dumpsys input` reports `Orientation: 0`, viewport `800×1280`, and
   `SurfaceOrientation: 0` — the mapping is correct.

### Home settings

Open Home settings directly:

```sh
adb shell am start -n com.android.launcher3/.settings.SettingsActivity
```

Trebuchet 18.1 has no "swipe down for notifications" preference (that arrived
in later Android versions), so the status-bar tap is the recommended gesture on
this build.

---

## 3. Current verified state

| Item | Value |
|---|---|
| OS | LineageOS 18.1 / Android 11 / `userdebug` |
| Build | `18.1-20240121-UNOFFICIAL-arm64_bvS` |
| Vendor | Android 10 / SDK 29 / `TB-8505X_USR_S301129_230914…` |
| System | GSI on `mmcblk0p37`, mounted at `/` |
| Vendor partition | `mmcblk0p36`, mounted at `/vendor` |
| Display | 800×1280, 240 dpi, working |
| Power key | sleep/wake verified (`Awake → Dozing/OFF → Awake/ON`) |
| Touch | `fts_ts`, `mtk-tpd`, `mtk-kpd` input devices |
| WiFi | scan works; not joined |
| Bluetooth | ON |
| Audio | `mt-snd-card`, AW87519 L/R, `tinyplay` played a WAV |
| Cameras | 2 devices exposed; Camera2 opens (preview dark in the test shot) |
| Sensors | accel, light, proximity, step counter, gestures |
| Root | `phh-su` → `uid=0`; adbd root via helper/watcher |
| Data | ~24 GB free, FBE encrypted |
| Battery | 87 %, charging |
| Screen timeout | 10 min (set for testing) |

Not covered: SIM/LTE, WiFi association, Bluetooth pairing, physical touch
accuracy, camera image quality.
