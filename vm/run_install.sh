#!/bin/sh
set -eu

# Run the ISO install (simulates real hardware): empty target disk on AHCI port 0
# (/dev/sata0), ISO as CD-ROM on port 1.
# Mode switches (see lib/qemu.sh): HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE
# Headless auto install needs the live root + ISO rebuilt with
# INSTALLER_ARGS=sata0 --yes first (see live/build_liveroot.sh).
# Overridable: VM_DISK (default target.vmdk), OUT_ISO (default leopard-installer.iso)

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
DISK="${VM_DISK:-$REPO/target.vmdk}"
ISO="${OUT_ISO:-$REPO/leopard-installer.iso}"

. "$ROOT/../lib/qemu.sh"
qemu_boot "$DISK" "$ISO"
