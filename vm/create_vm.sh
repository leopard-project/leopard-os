#!/bin/sh
set -eu

# Create an empty target disk (simulates a blank disk on real hardware).
# Environment: VM_DISK (default target.vmdk), VM_SIZE (default 5G),
#              VM_FORMAT=vmdk|raw (default vmdk; raw matches the beta XJ380.img style)

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
