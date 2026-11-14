#!/bin/sh
set -eu

# 引导预装镜像 image/XJ380.vmdk（无安装器）。
# 模式开关（见 lib/qemu.sh）：HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE

ROOT=$(cd "$(dirname "$0")" && pwd)

. "$ROOT/../lib/qemu.sh"
qemu_boot "$ROOT/XJ380.vmdk"
