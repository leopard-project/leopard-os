#!/bin/sh
set -eu

# 启动 ISO 安装（模拟真机）：空目标盘在 AHCI 端口 0（/dev/sata0），ISO 作 CD-ROM 在端口 1。
# 无头自动安装需先用 INSTALLER_ARGS='sata0 --yes' 重建 live root + ISO（见 build_liveroot.sh）。
# 可覆盖：VM_DISK（默认 target.vmdk）、OUT_ISO（默认 leopard-installer.iso）、
#          OVMF_FIRMWARE、QEMU_DISPLAY（默认 none，串口日志）、QEMU_SERIAL（默认 stdio）

ROOT=$(cd "$(dirname "$0")" && pwd)
DISK="${VM_DISK:-$ROOT/target.vmdk}"
ISO="${OUT_ISO:-$ROOT/leopard-installer.iso}"

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

exec qemu-system-x86_64 \
  -M q35 -bios "$OVMF" \
  -m 2048 -smp 4 \
  -drive if=none,id=hd,file="$DISK",format=vmdk \
  -device ahci,id=ahci -device ide-hd,bus=ahci.0,drive=hd \
  -drive if=none,id=cd,file="$ISO",media=cdrom \
  -device ide-cd,bus=ahci.1,drive=cd \
  -display "${QEMU_DISPLAY:-none}" -serial "${QEMU_SERIAL:-stdio}"
