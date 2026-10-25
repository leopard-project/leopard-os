#!/bin/sh
set -eu

# LeopardOS 安装介质 ISO 构建
#   live root（目录）→ live-root.img(XJPAK10) → efi.img(FAT32: BOOTX64.EFI+kernel.krl+live-root.img)
#   → ISO(El Torito EFI boot)
# 依赖：python3、mkfs.vfat、mtools(mmd/mcopy)、genisoimage
# 可覆盖：LIVEROOT、FAT_MIB、ISO_LABEL、OUT_ISO

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/.."

OUT_ISO="${OUT_ISO:-$ROOT/leopard-installer.iso}"
WORK="$ROOT/.iso"
EFI_IMG="$WORK/efi.img"
FAT_MIB="${FAT_MIB:-64}"
ISO_LABEL="${ISO_LABEL:-LEOPARD}"
LIVEROOT="${LIVEROOT:-$ROOT/liveroot}"

rm -rf "$WORK"
mkdir -p "$WORK"

[ -d "$LIVEROOT" ] || { echo "live root 目录不存在: $LIVEROOT" >&2; exit 1; }
python3 "$ROOT/tools/makepak.py" "$LIVEROOT" "$WORK/live-root.img"

dd if=/dev/zero of="$EFI_IMG" bs=1M count="$FAT_MIB" status=none
mkfs.vfat -F 32 "$EFI_IMG" >/dev/null 2>&1
mmd -i "$EFI_IMG" ::/EFI ::/EFI/BOOT ::/system
mcopy -i "$EFI_IMG" "$PROJ/OpenXSBoot/out/BOOTX64.efi" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$EFI_IMG" "$PROJ/OpenXSKernel/out/kernel.krl" ::/system/kernel.krl
mcopy -i "$EFI_IMG" "$WORK/live-root.img" ::/system/live-root.img
mcopy -i "$EFI_IMG" "$ROOT/boot.conf" ::/system/boot.conf

rm -f "$OUT_ISO"
genisoimage -o "$OUT_ISO" \
    -e efi.img -no-emul-boot \
    -V "$ISO_LABEL" \
    "$WORK"

rm -rf "$WORK"
echo "ISO 已生成: $OUT_ISO"
