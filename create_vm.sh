#!/bin/sh
set -eu

# 创建空目标盘（模拟真机安装的空硬盘），monolithicSparse vmdk
# 可覆盖：VM_DISK（默认 target.vmdk）、VM_SIZE（默认 1G）

ROOT=$(cd "$(dirname "$0")" && pwd)
DISK="${VM_DISK:-$ROOT/target.vmdk}"
SIZE="${VM_SIZE:-1G}"

qemu-img create -f vmdk -o subformat=monolithicSparse "$DISK" "$SIZE"

echo "虚拟机磁盘已创建: $DISK ($SIZE)"
