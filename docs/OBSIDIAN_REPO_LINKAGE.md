# Obsidian + Git linkage (host ↔ tablet)

Goal: keep notes in sync between Ubuntu and the tablet, optionally backed by
this git repository.

## Host setup

Create a vault (example):
```sh
mkdir -p ~/ObsidianVault
# initialize git if desired
cd ~/ObsidianVault
git init
git remote add origin git@github.com:rezasharifi82/TB8505X-lineage-os.git  # or a separate notes repo
```

Useful Obsidian plugins (host): Git, Sync, File Tree Alternative, etc.

## Sync to tablet (USB, works now)

```sh
ADB=~/tools/platform-tools/adb
$ADB push ~/ObsidianVault /sdcard/Documents/ObsidianVault
```

Or mount/share a folder. After editing on tablet, pull back:
```sh
$ADB pull /sdcard/Documents/ObsidianVault ~/ObsidianVault
```

## On tablet

Options:
1. **Obsidian** - install APK (from https://obsidian.md/download or GitHub
   releases). Open vault at `/sdcard/Documents/ObsidianVault`. If using git,
   commit/push with MGit/Termux.
2. **Markor** (installed) - simpler Markdown editor that can open the same folder
   and works well for quick edits.
3. **MGit** (installed) - clone this repo or a notes repo to tablet and sync.
4. **Termux + git** - full CLI workflow.

## Continuous sync (LAN)

1. Install **Syncthing-Fork** from F-Droid on tablet and `syncthing` on host.
2. Share `ObsidianVault` between them. This keeps them in sync automatically
   on the same network (WiFi/hotspot).

## Link this repo

The lineage repo docs and notes are staged on tablet at
`/sdcard/Documents/TB8505X-notes/`. You can:
- Clone `git@github.com:rezasharifi82/TB8505X-lineage-os.git` with MGit/Termux
- Keep a parallel Obsidian vault that references/link to copied docs
- Use Obsidian's "Open folder as vault" on `/sdcard/Documents/TB8505X-notes/` or a synced copy

Everything is ready for linking once Obsidian is installed.
