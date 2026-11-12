# LineageOS 18.1 GSI

The system image is **not committed** (1.85 GB). Fetch it with:

```sh
../../scripts/download_gsi.sh
```

Expected file:

```text
lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img
```

- Source: AndyYan's LineageOS 18.x GSI (SourceForge project `andyyan-gsi`)
- Android 11 / SDK 30, `userdebug`, vanilla + PHH superuser (`S`)
- `.img.xz` sha1 `f7ad2f8938818f4866dfbd2f9b718a99a55266a7`
- uncompressed `.img` sha1 `5807df9ebacb69f034d24c6b3082ecd5d4d327f0`
- expands to 1,884,483,584 bytes (sparse), fits the 4,085,252,096-byte system
  partition

The `download_gsi.sh` script tries several SourceForge mirrors, verifies the
SHA1 and decompresses to this directory.
