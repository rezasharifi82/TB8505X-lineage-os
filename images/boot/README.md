# Boot images

| File | Purpose |
|---|---|
| `boot_patched.img` | Stock Android 10 kernel + stock DTB + first-stage ramdisk, with `fstab.mt6761` patched so `/system` and `/vendor` no longer use `avb` and `/data` no longer uses `forcefdeorfbe`. This is the boot image that made the GSI boot. |
| `vbmeta_disabled.img` | Stock vbmeta with AVB flags `0x00000003` (hashtree + verification disabled). |

Hashes (sha256):

```text
f2356fd525cbc71e476253bd29c957b35f685c0acafb99cf2228c777ce553246  boot_patched.img
669023be75f5a17299c7564f3e4a700ebfc50b0a3acad68c7b4ae1a79a5dc0d5  vbmeta_disabled.img
```

`build/` contains the intermediate kernel/ramdisk/DTB extracted from the stock
boot and the patched ramdisk. It is git-ignored; it is only needed if you want
to rebuild `boot_patched.img`.

The stock boot/dtbo/vbmeta are **not** in this repository. They are private
partition dumps under `backups/brom_pre_unlock/`.
