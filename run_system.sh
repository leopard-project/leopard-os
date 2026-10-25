#!/bin/sh
set -eu

# 直接启动盘内已安装的系统（安装完成后的日常启动，无 ISO/CD）。
# 目标盘挂在 AHCI 端口 0（bootindex=0）直接引导。
# 模式开关（无需改脚本）：
#   HEADLESS=1   无头（-display none，纯串口）；默认图形窗口
#   QEMU_SERIAL  串口后端（默认 stdio，可设 file:/path 落日志）
#   QEMU_DISPLAY 显示后端覆盖（高级）
# 可覆盖：VM_DISK（默认 target.vmdk）、OVMF_FIRMWARE

ROOT=$(cd "$(dirname "$0")" && pwd)
DISK="${VM_DISK:-$ROOT/target.vmdk}"

# 按候选顺序找 OVMF 固件（可用 OVMF_FIRMWARE 覆盖）
OVMF=""
for f in \
    "${OVMF_FIRMWARE:-}" \
    /usr/share/ovmf/OVMF.fd \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
do
    [ -n "$f" ] && [ -f "$f" ] && [ -r "$f" ] && OVMF="$f" && break
done

[ -n "$OVMF" ] || { echo "找不到 OVMF 固件，请 OVMF_FIRMWARE=/path 指定" >&2; exit 1; }
echo "使用固件: $OVMF"

# 无头/图形开关
if [ "${HEADLESS:-0}" = "1" ]; then
    DISPLAY_ARG="none"
elif [ -n "${QEMU_DISPLAY:-}" ]; then
    DISPLAY_ARG="$QEMU_DISPLAY"
else
    DISPLAY_ARG=""
fi

set -- qemu-system-x86_64 \
  -M q35 -bios "$OVMF" \
  -m 2048 -smp 4 \
  -drive if=none,id=hd,file="$DISK",format=vmdk \
  -device ahci,id=ahci -device ide-hd,bus=ahci.0,drive=hd,bootindex=0
if [ -n "$DISPLAY_ARG" ]; then set -- "$@" -display "$DISPLAY_ARG"; fi
set -- "$@" -serial "${QEMU_SERIAL:-stdio}"

exec "$@"
