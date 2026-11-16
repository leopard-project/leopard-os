#!/bin/sh
set -eu

# Boot the system already installed on the disk (day-to-day boot after install,
# no ISO/CD).
# The target disk sits on AHCI port 0 (bootindex=0) and boots directly.
# Mode switches (see lib/qemu.sh): HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE
# Overridable: VM_DISK (default target.vmdk)

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
DISK="${VM_DISK:-$REPO/target.vmdk}"

. "$ROOT/../lib/qemu.sh"
qemu_boot "$DISK"
