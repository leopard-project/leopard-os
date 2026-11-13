# lib/qemu.sh — QEMU 启动共用样板（参考 2026-11-11 官方内测指南）
# 被 run_install.sh / run_system.sh / img-tools/run.sh 共用。
# 提供：qemu_boot <disk> [iso]
#
# 常用环境变量：
#   HEADLESS=1            无显示（测试默认）
#   QEMU_SERIAL=...       stdio（默认）/ file:/path
#   QEMU_DISPLAY=gtk     非 headless 时的显示后端
#   OVMF_FIRMWARE=...     固件路径
#   QEMU_MEM=2048         内存 MiB
#   QEMU_SMP=4            vCPU 数
#   QEMU_ACCEL=auto       auto / kvm / tcg
#   QEMU_DISK_BUS=sata    sata / nvme（兼容性测试）
#   QEMU_NET=1            加 e1000 + user net（hostfwd 2323）
#   QEMU_AUDIO=1          加 ich9-hda + sdl 音频（需要显示）
#   QEMU_GDB=1            -s（gdb :1234）；QEMU_PAUSE=1 再加 -S
#   QEMU_NO_REBOOT=1      -no-reboot（测试用）
#   QEMU_STRICT_BOOT=0    关闭 -boot strict=on

# 找 OVMF 固件（OVMF_FIRMWARE 覆盖），找不到则退出
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
#   有 iso：CD bootindex=0，硬盘 bootindex=1（先装系统）
#   无 iso：硬盘 bootindex=0（直接引导盘内系统）
qemu_boot() {
    DISK="$1"
    ISO="${2:-}"
    qemu_find_ovmf

    # 磁盘格式：显式 QEMU_DISK_FORMAT，否则按扩展名
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

    # 输入设备：Leopard 内核默认只带 PS/2 键鼠；USB HID 需要 CONFIG_KERNEL_BUILTIN_XHCI。
    # 官方内测镜像（USB 输入）可用 QEMU_USB=1 切到 xHCI/USB。
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

    # 测试用：-no-reboot 让「重启」直接退出 QEMU
    if [ "${QEMU_NO_REBOOT:-0}" = "1" ]; then set -- "$@" -no-reboot; fi

    exec "$@"
}
