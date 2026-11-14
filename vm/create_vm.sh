#!/bin/sh
set -eu

# 创建空目标盘（模拟真机安装的空硬盘）。
# 环境变量：VM_DISK（默认 target.vmdk）、VM_SIZE（默认 5G）、
#           VM_FORMAT=vmdk|raw（默认 vmdk；raw 对应内测的 XJ380.img 风格）

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
DISK="${VM_DISK:-$REPO/target.vmdk}"
SIZE="${VM_SIZE:-5G}"
FORMAT="${VM_FORMAT:-vmdk}"

case "$FORMAT" in
    vmdk)
        qemu-img create -f vmdk -o subformat=monolithicSparse "$DISK" "$SIZE"
        ;;
    raw)
        qemu-img create -f raw "$DISK" "$SIZE"
        ;;
    *)
        echo "VM_FORMAT 只支持 vmdk 或 raw（当前: $FORMAT）" >&2
        exit 1
        ;;
esac

echo "虚拟机磁盘已创建: $DISK ($SIZE, $FORMAT)"
