#!/bin/sh
set -eu

# Boot the preinstalled image image/XJ380.vmdk (no installer).
# Mode switches (see lib/qemu.sh): HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE

ROOT=$(cd "$(dirname "$0")" && pwd)

. "$ROOT/../lib/qemu.sh"
qemu_boot "$ROOT/XJ380.vmdk"
