# lib/qemu.sh — shared QEMU launch boilerplate (per the 2026-11-11 official beta guide)
# Shared by vm/run_install.sh / vm/run_system.sh / image/run_image.sh.
# Provides: qemu_boot <disk> [iso]
#
# Common environment variables:
#   HEADLESS=1            no display (test default)
#   QEMU_SERIAL=...       stdio (default) / file:/path
#   QEMU_DISPLAY=gtk      display backend when not headless
#   OVMF_FIRMWARE=...     firmware path
#   QEMU_MEM=2048         memory MiB
#   QEMU_SMP=4            vCPU count
#   QEMU_ACCEL=auto       auto / kvm / tcg
#   QEMU_DISK_BUS=sata    sata / nvme (compatibility tests)
#   QEMU_NET=1            add e1000 + user net (hostfwd 2323)
#   QEMU_AUDIO=1          add ich9-hda + sdl audio (needs a display)
#   QEMU_GDB=1            -s (gdb :1234); QEMU_PAUSE=1 also adds -S
#   QEMU_NO_REBOOT=1      -no-reboot (for tests)
#   QEMU_STRICT_BOOT=0    disable -boot strict=on

# Locate OVMF firmware (OVMF_FIRMWARE overrides); exit if not found
qemu_find_ovmf() {
    OVMF=""
    for f in "${OVMF_FIRMWARE:-}" /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
        [ -n "$f" ] && [ -f "$f" ] && [ -r "$f" ] && OVMF="$f" && break
    done
    [ -n "$OVMF" ] || { echo "找不到 OVMF 固件，请 OVMF_FIRMWARE=/path 指定" >&2; exit 1; }
    echo "使用固件: $OVMF"
}

qemu_has_kvm() {
    [ -r /dev/kvm ] && [ -w /dev/kvm ]
}

# qemu_boot <disk> [iso]
#   with iso: CD bootindex=0, disk bootindex=1 (install first)
#   no iso: disk bootindex=0 (boot the installed system directly)
qemu_boot() {
    DISK="$1"
    ISO="${2:-}"
    qemu_find_ovmf

    # Disk format: explicit QEMU_DISK_FORMAT, otherwise by extension
    FORMAT="${QEMU_DISK_FORMAT:-}"
    if [ -z "$FORMAT" ]; then
        case "$DISK" in
            *.img)  FORMAT=raw ;;
            *.vmdk) FORMAT=vmdk ;;
            *)      FORMAT=raw ;;
        esac
    fi

    MEM="${QEMU_MEM:-2048}"
    SMP="${QEMU_SMP:-4}"
    BUS="${QEMU_DISK_BUS:-sata}"
    ACCEL="${QEMU_ACCEL:-auto}"
    if [ "$ACCEL" = "auto" ]; then
        if qemu_has_kvm; then ACCEL=kvm; else ACCEL=tcg; fi
    fi

    set -- qemu-system-x86_64 -M q35 -bios "$OVMF" -m "$MEM" -smp "$SMP"
    if [ "$ACCEL" = "kvm" ]; then
        set -- "$@" -enable-kvm -cpu host
    else
        set -- "$@" -cpu max
    fi

    # Input devices: the Leopard kernel ships PS/2 keyboard/mouse only; USB HID
    # needs CONFIG_KERNEL_BUILTIN_XHCI. For the official beta image (USB input)
    # set QEMU_USB=1 to switch to xHCI/USB.
    if [ "${QEMU_USB:-0}" = "1" ]; then
        set -- "$@" -device qemu-xhci,id=xhci \
            -device usb-kbd,bus=xhci.0,port=1 \
            -device usb-mouse,bus=xhci.0,port=2
    else
        set -- "$@" -device qemu-xhci,id=xhci
    fi

    if [ -n "$ISO" ]; then
        set -- "$@" -device ahci,id=ahci \
            -drive if=none,id=hd,file="$DISK",format="$FORMAT" \
            -device ide-hd,bus=ahci.0,drive=hd,bootindex=1 \
            -drive if=none,id=cd,file="$ISO",media=cdrom \
            -device ide-cd,bus=ahci.1,drive=cd,bootindex=0
    else
        case "$BUS" in
            nvme)
                set -- "$@" -drive if=none,id=hd,file="$DISK",format="$FORMAT" \
                    -device nvme,serial=leopard,drive=hd,bootindex=0
                ;;
            *)
                set -- "$@" -device ahci,id=ahci \
                    -drive if=none,id=hd,file="$DISK",format="$FORMAT" \
                    -device ide-hd,bus=ahci.0,drive=hd,bootindex=0
                ;;
        esac
    fi

    if [ "${QEMU_STRICT_BOOT:-1}" = "1" ]; then
        set -- "$@" -boot strict=on
    fi

    if [ "${QEMU_NET:-0}" = "1" ]; then
        set -- "$@" -netdev "user,id=net0,hostfwd=tcp::${QEMU_HOSTFWD:-2323}-:2323" \
            -device e1000,netdev=net0
    fi

    if [ "${HEADLESS:-0}" = "1" ]; then
        DISPLAY_ARG="none"
    elif [ -n "${QEMU_DISPLAY:-}" ]; then
        DISPLAY_ARG="$QEMU_DISPLAY"
    else
        DISPLAY_ARG=""
    fi
    if [ -n "$DISPLAY_ARG" ]; then set -- "$@" -display "$DISPLAY_ARG"; fi

    if [ "${QEMU_AUDIO:-0}" = "1" ] && [ "${HEADLESS:-0}" != "1" ]; then
        set -- "$@" -audiodev "${QEMU_AUDIODEV:-sdl,id=snd0}" \
            -device ich9-intel-hda \
            -device hda-output,use-timer=off,audiodev=snd0
    fi

    set -- "$@" -serial "${QEMU_SERIAL:-stdio}"

    if [ "${QEMU_GDB:-0}" = "1" ]; then set -- "$@" -s; fi
    if [ "${QEMU_PAUSE:-0}" = "1" ]; then set -- "$@" -S; fi

    # For tests: -no-reboot makes a "reboot" exit QEMU directly
    if [ "${QEMU_NO_REBOOT:-0}" = "1" ]; then set -- "$@" -no-reboot; fi

    exec "$@"
}
