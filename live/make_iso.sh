#!/bin/sh
set -eu

# =====================================================================
# LeopardOS install media ISO build (MBR + appended partition, dd-able to a USB stick)
#
# Layout:
#   live root → live-root.img (XJPAK10)
#   efi.img   = FAT32 image holding BOOTX64.EFI, kernel.krl, live-root.img
#   ISO       = MBR partition table + El Torito:
#               - the MBR holds one 0xEF-type partition pointing at efi.img
#               - the same efi.img also serves as the El Torito EFI boot image
#
# Compatibility:
#   * dd to USB   → UEFI firmware loads \EFI\BOOT\BOOTX64.EFI via the 0xef MBR partition
#   * burned disc → uses El Torito (efi.img must be <= 32 MiB)
#
# Dependencies: python3, dosfstools, mtools, xorriso
# =====================================================================

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
PROJ=$(cd "$REPO/.." && pwd)

OUT_ISO="${OUT_ISO:-$REPO/leopard-installer.iso}"
WORK="$REPO/.iso"
EFI_IMG="$WORK/efi.img"
FAT_MIB="${FAT_MIB:-64}"
ISO_LABEL="${ISO_LABEL:-LEOPARD}"
LIVEROOT="${LIVEROOT:-$REPO/liveroot}"

# ---- dependency check ---------------------------------------------------
missing=""
for c in python3 dd mkfs.vfat mmd mcopy xorriso; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
done
if [ -n "$missing" ]; then
    echo "缺少依赖:$missing" >&2
    echo "请安装: sudo apt install dosfstools mtools xorriso" >&2
    exit 1
fi

# ---- prepare work directory ---------------------------------------------
rm -rf "$WORK"
mkdir -p "$WORK"
[ -d "$LIVEROOT" ] || { echo "live root 目录不存在: $LIVEROOT" >&2; exit 1; }

# ---- pack live root ----------------------------------------------------
# Defense in depth: make_iso may also consume an already assembled liveroot.
# PE executables without the x bit make initrd boot report "Not Executable".
find "$LIVEROOT/apps" "$LIVEROOT/system" -type f -name '*.elf' \
    -exec chmod 0755 {} + 2>/dev/null || true
for f in "$LIVEROOT"/apps/system/xbps-*; do
    [ -e "$f" ] && chmod 0755 "$f"
done

echo "打包 live root → live-root.img ..."
python3 "$ROOT/makepak.py" "$LIVEROOT" "$WORK/live-root.img"

# ---- build FAT32 ESP ---------------------------------------------------
echo "构建 FAT32 ESP (${FAT_MIB} MiB) ..."
dd if=/dev/zero of="$EFI_IMG" bs=1M count="$FAT_MIB" status=none
mkfs.vfat -F 32 "$EFI_IMG" >/dev/null 2>&1
mmd  -i "$EFI_IMG" ::/EFI ::/EFI/BOOT ::/system
mcopy -i "$EFI_IMG" "$PROJ/leopard-boot/out/BOOTX64.efi"  ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$EFI_IMG" "$PROJ/leopard-xsk/out/kernel.krl" ::/system/kernel.krl
mcopy -i "$EFI_IMG" "$WORK/live-root.img"               ::/system/live-root.img
mcopy -i "$EFI_IMG" "$ROOT/boot.conf"                   ::/system/boot.conf

# ---- warn about the El Torito 32 MiB limit -----------------------------
if [ "$FAT_MIB" -gt 32 ]; then
    echo "" >&2
    echo "注意: FAT_MIB=${FAT_MIB} > 32 MiB。" >&2
    echo "      El Torito 的扇区计数字段只有 16 位，超过 32 MiB 会被截断。" >&2
    echo "      → 刻录光盘启动可能失败。" >&2
    echo "      → dd 到 U 盘后的 UEFI 启动不受影响（走 MBR 的 0xef 分区）。" >&2
    echo "" >&2
fi

# ---- generate ISO (MBR + appended partition) ---------------------------
echo "生成 ISO ..."
rm -f "$OUT_ISO"
xorriso -as mkisofs -o "$OUT_ISO" \
    -V "$ISO_LABEL" \
    -rational-rock \
    -partition_offset 16 \
    -append_partition 2 0xef "$EFI_IMG" \
    -eltorito-alt-boot \
    --efi-boot --interval:appended_partition_2:all:: \
    -no-emul-boot \
    "$WORK"

rm -rf "$WORK"

echo ""
echo "ISO 已生成: $OUT_ISO"
echo ""
echo "写入 U 盘:"
echo "  sudo dd if=\"$OUT_ISO\" of=/dev/sdX bs=4M status=progress oflag=sync"
echo ""
echo "写入后验证 (应看到 Type=EFI 的分区):"
echo "  sudo fdisk -l /dev/sdX"