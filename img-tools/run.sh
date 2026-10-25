#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)

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
  -drive if=none,id=hd,file="$ROOT/XJ380.vmdk",format=vmdk \
  -device ahci,id=ahci -device ide-hd,bus=ahci.0,drive=hd,bootindex=0 \
  -serial stdio

