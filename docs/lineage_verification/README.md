# Verification screenshots (2026-11-12)

These were captured from the live tablet over ADB after the verified flash.

| File | What it proves |
|---|---|
| `01-setup-date-time.png` | Panel and compositor render the LineageOS setup wizard at 800×1280. |
| `02-home.png` | Trebuchet home screen after setup; status bar, dock, wallpaper. |
| `03-after-wake.png` | Screen still renders after `input keyevent 26` sleep/wake cycle. |
| `04-camera.png` | Camera2 app launches (preview was dark in the test shot). |
| `05-app-drawer.png` | App drawer populated (AudioFX, Browser, Calculator, Calendar, Camera, Clock, Contacts, Files, Gallery, Messaging, Music, Phone, Recorder, Settings). |
| `06-notification-shade.png` | Notification shade opens (here via `adb shell cmd statusbar expand-notifications`; a status-bar tap also works). |

The display was the blocker in the Ubuntu Touch port; these screenshots show it
working under LineageOS.
