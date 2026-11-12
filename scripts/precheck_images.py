#!/usr/bin/env python3
"""Image-level preflight for the TB-8505X LineageOS/GSI flash.

Validates every file BEFORE anything is written to the tablet:
  - stock vendor ext4 (build.prop, required dirs, fsck)
  - patched boot image (header, kernel gzip/ARM64, ramdisk cpio, fstab flags, dtb)
  - stock dtbo (MTK magic, size)
  - vbmeta (AVB0, flags = 3)
  - GSI archive + sparse structure + ext4 contents + fsck
  - all sizes against the real partition sizes
"""
import gzip
import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.environ.get("TB8505X_ROOT", os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

VENDOR = f"{ROOT}/backups/brom_full_20261110_210125/vendor.bin"
BOOT = f"{ROOT}/images/boot/boot_patched.img"
DTBO = f"{ROOT}/backups/brom_pre_unlock/dtbo.bin"
VBMETA = f"{ROOT}/images/boot/vbmeta_disabled.img"
GSI_XZ = f"{ROOT}/images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img.xz"
GSI = f"{ROOT}/images/gsi/lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img"

VENDOR_SHA256 = "2c2933226efdd88ad9bdf5cd6443a7edf623e441ec95616020af3b318fbe9e50"
DTBO_SHA256 = "684d5bba65e027526cd2f36685bd454a7b0737b79c7e1559e54faa86890aa5f3"
GSI_SHA1 = "f7ad2f8938818f4866dfbd2f9b718a99a55266a7"

VENDOR_PART = 0x32000000
BOOT_PART = 0x2000000
DTBO_PART = 0x800000
VBMETA_PART = 0x800000
SYSTEM_PART = 0xF3800000

OK = "\033[0;32m[ OK ]\033[0m"
BAD = "\033[0;31m[FAIL]\033[0m"
WARN = "\033[0;33m[WARN]\033[0m"

errors = []
warnings = []


def good(msg):
    print(f"{OK} {msg}")


def bad(msg):
    print(f"{BAD} {msg}")
    errors.append(msg)


def warn(msg):
    print(f"{WARN} {msg}")
    warnings.append(msg)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def need(path, label):
    if not os.path.isfile(path):
        bad(f"{label}: missing {path}")
        return False
    return True


def check_vendor():
    print("\n--- vendor (stock Android 10) ---")
    if not need(VENDOR, "vendor"):
        return
    size = os.path.getsize(VENDOR)
    if size != VENDOR_PART:
        bad(f"vendor size {size} != partition {VENDOR_PART}")
    else:
        good(f"vendor size {size} == partition size")
    got = sha256(VENDOR)
    if got != VENDOR_SHA256:
        bad(f"vendor sha256 {got} != {VENDOR_SHA256}")
    else:
        good("vendor sha256 matches the verified backup")

    ftype = run(["file", "-b", VENDOR]).stdout.strip()
    if "ext2 filesystem" not in ftype and "ext4 filesystem" not in ftype:
        bad(f"vendor is not ext4: {ftype}")
    else:
        good("vendor is an ext2/ext4 filesystem")

    r = run(["e2fsck", "-fn", VENDOR])
    if r.returncode != 0:
        bad(f"vendor e2fsck failed (rc={r.returncode}): {r.stdout[-300:]}")
    else:
        good("vendor e2fsck clean")

    r = run(["debugfs", "-R", "cat /build.prop", VENDOR])
    props = dict(
        line.split("=", 1)
        for line in r.stdout.splitlines()
        if "=" in line and not line.startswith("#")
    )
    rel = props.get("ro.vendor.build.version.release")
    sdk = props.get("ro.vendor.build.version.sdk")
    inc = props.get("ro.vendor.build.version.incremental", "")
    if rel == "10" and sdk == "29":
        good(f"vendor build: Android {rel} / SDK {sdk} / {inc}")
    else:
        bad(f"unexpected vendor build: release={rel} sdk={sdk}")

    for d in ["/bin", "/lib64", "/etc", "/firmware", "/lib"]:
        r = run(["debugfs", "-R", f"stat {d}", VENDOR])
        if "Inode:" in r.stdout:
            good(f"vendor contains {d}")
        else:
            bad(f"vendor missing {d}")


def pad(n, ps=2048):
    return ((n + ps - 1) // ps) * ps


def check_boot():
    print("\n--- boot (stock kernel + patched fstab) ---")
    if not need(BOOT, "boot"):
        return
    d = open(BOOT, "rb").read()
    if d[:8] != b"ANDROID!":
        bad("boot magic is not ANDROID!")
        return
    good("boot magic ANDROID!")
    ks, = struct.unpack_from("<I", d, 8)
    rs, = struct.unpack_from("<I", d, 16)
    ps, = struct.unpack_from("<I", d, 0x24)
    hv, = struct.unpack_from("<I", d, 0x28)
    dsz, = struct.unpack_from("<I", d, 0x670)
    if hv != 2:
        bad(f"boot header version {hv}, expected 2")
    else:
        good("boot header version 2")
    if ps != 2048:
        bad(f"boot page size {ps}, expected 2048")
    else:
        good("boot page size 2048")
    off = ps
    if len(d) < off + pad(ks) + pad(rs) + dsz:
        bad("boot image is truncated (kernel/ramdisk/dtb extend past EOF)")
        return
    kernel = d[off:off + ks]
    off += pad(ks)
    ramdisk = d[off:off + rs]
    off += pad(rs)
    dtb = d[off:off + dsz]

    try:
        import zlib
        z = zlib.decompressobj(16 + zlib.MAX_WBITS)
        raw = z.decompress(kernel) + z.flush()
        if raw[0x38:0x3c] == b"ARMd":
            good(f"kernel: gzip, {len(raw)} bytes, ARM64 Image magic at 0x38")
        else:
            bad(f"kernel decompresses but ARM64 magic missing: {raw[0x38:0x3c]!r}")
        tail = z.unused_data
        if tail:
            if tail[:4] == b"\xd0\x0d\xfe\xed":
                good(f"kernel tail: appended FDT (d00dfeed), {len(tail)} bytes")
            else:
                warn(f"kernel tail: {len(tail)} bytes, magic {tail[:4].hex()}")
    except Exception as e:
        bad(f"kernel is not valid gzip: {e}")

    try:
        rraw = gzip.decompress(ramdisk)
    except Exception as e:
        bad(f"ramdisk is not valid gzip: {e}")
        return
    good(f"ramdisk: gzip, {len(rraw)} bytes")
    tmp = tempfile.mkdtemp(prefix="pre-boot-")
    try:
        p = subprocess.run(["cpio", "-it"], input=rraw, cwd=tmp,
                           capture_output=True)
        listing = p.stdout.decode("latin1", "replace").split()
        names = {n.lstrip("./") for n in listing}
        for f in ["init", "fstab.mt6761"]:
            if f in names:
                good(f"ramdisk contains {f}")
            else:
                bad(f"ramdisk missing {f}")

        subprocess.run(["cpio", "-idm", "--no-absolute-filenames"],
                       input=rraw, cwd=tmp, capture_output=True)
        fstab = os.path.join(tmp, "fstab.mt6761")
        if os.path.isfile(fstab):
            txt = open(fstab).read()
            for line in txt.splitlines():
                if line.startswith("/dev/block") and " /system " in line:
                    if "avb" in line:
                        bad("fstab /system still has avb= (verity) flag")
                    elif "first_stage_mount" not in line:
                        bad("fstab /system missing first_stage_mount")
                    else:
                        good("fstab /system: first_stage_mount, no avb")
                if line.startswith("/dev/block") and " /vendor " in line:
                    if "avb" in line:
                        bad("fstab /vendor still has avb= (verity) flag")
                    else:
                        good("fstab /vendor: no avb")
                if line.startswith("/dev/block") and " /data " in line:
                    if "forcefdeorfbe" in line:
                        bad("fstab /data still has forcefdeorfbe=")
                    elif "encryptable=" in line:
                        good("fstab /data: encryptable (no forced FBE)")
                    else:
                        warn("fstab /data has neither forcefdeorfbe nor encryptable")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if dsz == 0:
        bad("boot dtb is empty (stock boot had a 99298-byte MTK dtb)")
    else:
        if dtb[:4] == bytes.fromhex("d7b7ab1e"):
            good(f"boot dtb: MTK magic d7b7ab1e, {dsz} bytes")
        else:
            bad(f"boot dtb magic {dtb[:4].hex()} (expected d7b7ab1e)")

    if len(d) > BOOT_PART:
        bad(f"boot image {len(d)} > boot partition {BOOT_PART}")
    else:
        good(f"boot image {len(d)} fits boot partition {BOOT_PART}")


def check_dtbo():
    print("\n--- dtbo (stock) ---")
    if not need(DTBO, "dtbo"):
        return
    size = os.path.getsize(DTBO)
    if size > DTBO_PART:
        bad(f"dtbo {size} > partition {DTBO_PART}")
    else:
        good(f"dtbo size {size} fits partition {DTBO_PART}")
    got = sha256(DTBO)
    if got != DTBO_SHA256:
        bad(f"dtbo sha256 {got} != {DTBO_SHA256}")
    else:
        good("dtbo sha256 matches the verified stock backup")
    magic = open(DTBO, "rb").read(4).hex()
    if magic == "d7b7ab1e":
        good("dtbo has MTK magic d7b7ab1e")
    else:
        bad(f"dtbo magic {magic} (expected d7b7ab1e)")


def check_vbmeta():
    print("\n--- vbmeta (verification disabled) ---")
    if not need(VBMETA, "vbmeta"):
        return
    d = open(VBMETA, "rb").read()
    if d[:4] != b"AVB0":
        bad("vbmeta magic is not AVB0")
    else:
        good("vbmeta magic AVB0")
    flags = d[120:124].hex()
    if d[123] == 3:
        good(f"vbmeta flags {flags} = HASHTREE_DISABLED|VERIFICATION_DISABLED")
    else:
        bad(f"vbmeta flags byte is {d[123]} (expected 3)")
    if len(d) > VBMETA_PART:
        bad(f"vbmeta {len(d)} > partition {VBMETA_PART}")
    else:
        good(f"vbmeta size {len(d)} fits partition {VBMETA_PART}")


def check_gsi():
    print("\n--- LineageOS 18.1 GSI ---")
    if not need(GSI_XZ, "GSI archive"):
        return
    got = sha1(GSI_XZ)
    if got == GSI_SHA1:
        good("GSI .xz sha1 matches the documented build")
    else:
        bad(f"GSI .xz sha1 {got} != {GSI_SHA1}")
    if not need(GSI, "GSI image"):
        return

    size = os.path.getsize(GSI)
    print(f"       GSI file size: {size} bytes")
    with open(GSI, "rb") as f:
        hdr = f.read(28)
    if len(hdr) < 28:
        bad("GSI too small for a sparse header")
        return
    magic, maj, mnr, fh, ch, blk, tblk, tchk, csum = struct.unpack("<I4H4I", hdr)
    if magic != 0xED26FF3A:
        bad(f"GSI sparse magic {magic:#x} != 0xed26ff3a")
        return
    good(f"GSI sparse header: {tchk} chunks, {tblk} blocks of {blk}")
    total_out = tblk * blk
    if total_out > SYSTEM_PART:
        bad(f"GSI expands to {total_out} > system partition {SYSTEM_PART}")
    else:
        good(f"GSI expands to {total_out} bytes, fits system partition {SYSTEM_PART}")

    with open(GSI, "rb") as f:
        f.seek(fh)
        largest = 0
        for i in range(tchk):
            h = f.read(ch)
            if len(h) < ch:
                bad(f"GSI truncated at chunk {i}")
                return
            t, _, csz, tsz = struct.unpack_from("<2H2I", h, 0)
            data = tsz - ch
            largest = max(largest, data)
            f.seek(data, 1)
    good(f"largest sparse chunk: {largest} bytes")
    if largest > 0x8000000:
        warn(f"largest chunk > max-download-size (0x8000000); fastboot will re-split")
    else:
        good("largest chunk within max-download-size 0x8000000")

    simg = os.path.join(ROOT, "..", "buildtmp", "simg2img")
    if not os.path.exists(simg):
        simg = shutil.which("simg2img") or simg
    tmp = tempfile.mkdtemp(prefix="pre-gsi-")
    raw = os.path.join(tmp, "gsi.raw")
    try:
        r = run([simg, GSI, raw])
        if r.returncode != 0:
            bad(f"simg2img failed: {r.stderr[-300:]}")
            return
        if os.path.getsize(raw) != total_out:
            bad(f"simg2img output {os.path.getsize(raw)} != sparse total {total_out}")
        else:
            good("simg2img expanded the GSI to the expected size")
        ftype = run(["file", "-b", raw]).stdout.strip()
        if "ext2 filesystem" in ftype or "ext4 filesystem" in ftype:
            good("GSI raw image is ext4")
        else:
            bad(f"GSI raw image is not ext4: {ftype}")
        r = run(["e2fsck", "-fn", raw])
        if r.returncode != 0:
            bad(f"GSI e2fsck failed (rc={r.returncode}): {r.stdout[-300:]}")
        else:
            good("GSI e2fsck clean")
        r = run(["debugfs", "-R", "cat /system/build.prop", raw])
        props = dict(
            line.split("=", 1)
            for line in r.stdout.splitlines()
            if "=" in line and not line.startswith("#")
        )
        rel = props.get("ro.build.version.release")
        sdk = props.get("ro.build.version.sdk")
        lin = props.get("ro.lineage.version", "")
        typ = props.get("ro.build.type", "")
        if rel == "11" and sdk == "30":
            good(f"GSI build: Android {rel} / SDK {sdk} / {typ} / {lin}")
        else:
            bad(f"unexpected GSI build: release={rel} sdk={sdk} type={typ} line={lin}")
        for p in ["/system/bin/init", "/system/etc/init/hw/init.rc"]:
            r = run(["debugfs", "-R", f"stat {p}", raw])
            if "Inode:" in r.stdout:
                good(f"GSI contains {p}")
            else:
                bad(f"GSI missing {p}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    print("=" * 70)
    print(" TB-8505X image preflight (nothing is written to the tablet)")
    print("=" * 70)
    for t in ["file", "e2fsck", "debugfs", "cpio", "gzip"]:
        if not shutil.which(t):
            bad(f"host tool missing: {t}")

    check_vendor()
    check_boot()
    check_dtbo()
    check_vbmeta()
    check_gsi()

    print("\n" + "=" * 70)
    if errors:
        print(f" RESULT: FAIL — {len(errors)} error(s), {len(warnings)} warning(s)")
        for e in errors:
            print(f"   - {e}")
        return 1
    print(f" RESULT: PASS — 0 errors, {len(warnings)} warning(s)")
    for w in warnings:
        print(f"   - {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
