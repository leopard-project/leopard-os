# lib/qemu.sh — QEMU 启动共用样板
# 被 run_install.sh / run_system.sh / img-tools/run.sh 共用。
# 提供：qemu_boot <disk> [iso]
# 环境变量：HEADLESS / QEMU_SERIAL / QEMU_DISPLAY / OVMF_FIRMWARE

# 找 OVMF 固件（OVMF_FIRMWARE 覆盖），找不到则退出
qemu_find_ovmf() {
    OVMF=""
    for f in "${OVMF_FIRMWARE:-}" /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
        [ -n "$f" ] && [ -f "$f" ] && [ -r "$f" ] && OVMF="$f" && break
    done
    [ -n "$OVMF" ] || { echo "找不到 OVMF 固件，请 OVMF_FIRMWARE=/path 指定" >&2; exit 1; }
    echo "使用固件: $OVMF"
}

# qemu_boot <disk> [iso]
#   有 iso：挂 CD 到 ahci.1，hd 不设 bootindex（从 CD 引导安装）
#   无 iso：hd 设 bootindex=0（直接引导盘内系统）
qemu_boot() {
    DISK="$1"
    ISO="${2:-}"
    qemu_find_ovmf

    if [ "${HEADLESS:-0}" = "1" ]; then
        DISPLAY_ARG="none"
    elif [ -n "${QEMU_DISPLAY:-}" ]; then
        DISPLAY_ARG="$QEMU_DISPLAY"
    else
        DISPLAY_ARG=""
    fi

    set -- qemu-system-x86_64 -M q35 -bios "$OVMF" -m 2048 -smp 4 -drive if=none,id=hd,file="$DISK",format=vmdk -device ahci,id=ahci
    if [ -n "$ISO" ]; then
        set -- "$@" -device ide-hd,bus=ahci.0,drive=hd -drive if=none,id=cd,file="$ISO",media=cdrom -device ide-cd,bus=ahci.1,drive=cd
    else
        set -- "$@" -device ide-hd,bus=ahci.0,drive=hd,bootindex=0
    fi
    if [ -n "$DISPLAY_ARG" ]; then set -- "$@" -display "$DISPLAY_ARG"; fi
    set -- "$@" -serial "${QEMU_SERIAL:-stdio}"
    exec "$@"
}
