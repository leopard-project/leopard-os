#!/bin/sh
set -eu

# 直接启动盘内已安装的系统（安装完成后的日常启动，无 ISO/CD）。
# 目标盘挂 AHCI 端口 0（bootindex=0）直接引导。
# 模式开关（见 lib/qemu.sh）：HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE
# 可覆盖：VM_DISK（默认 target.vmdk）

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
DISK="${VM_DISK:-$REPO/target.vmdk}"

. "$ROOT/../lib/qemu.sh"
qemu_boot "$DISK"
