#!/bin/sh
set -eu

# 启动 ISO 安装（模拟真机）：空目标盘在 AHCI 端口 0（/dev/sata0），ISO 作 CD-ROM 在端口 1。
# 模式开关（见 lib/qemu.sh）：HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE
# 无头自动安装需先用 INSTALLER_ARGS=sata0 --yes 重建 live root + ISO（见 live/build_liveroot.sh）。
# 可覆盖：VM_DISK（默认 target.vmdk）、OUT_ISO（默认 leopard-installer.iso）

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
DISK="${VM_DISK:-$REPO/target.vmdk}"
ISO="${OUT_ISO:-$REPO/leopard-installer.iso}"

. "$ROOT/../lib/qemu.sh"
qemu_boot "$DISK" "$ISO"
