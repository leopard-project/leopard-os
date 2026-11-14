#!/bin/sh
set -eu

# 一键无头安装测试：空盘 -> live ISO -> 零输入自动安装 -> 断言串口日志。
#
# 优化点：
#   - auto 安装使用 finish=shutdown，装完立即关机，不再空等 TIMEOUT；
#   - 日志出现完成/失败标记后主动结束 QEMU（wait_for_log），单次测试更快；
#   - 失败时自动打印日志尾部，便于定位。
#
# 环境变量：
#   BUILD=1        先打包所有组件（默认 0，假定已构建）
#   TIMEOUT=300    最长等待秒数（有早期退出，通常远小于它）
#   WORK=路径       工作目录（默认 .testwork）
#   KEEP=1         保留工作目录（默认清理）

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
WORK="${WORK:-$REPO/.testwork}"
TIMEOUT="${TIMEOUT:-300}"
ISO="$WORK/leopard-installer.iso"
DISK="$WORK/target.vmdk"
LOG="$WORK/install.log"

. "$REPO/lib/logcheck.sh"

rm -rf "$WORK"
mkdir -p "$WORK"

if [ "${BUILD:-0}" = "1" ]; then
    echo ">>> 打包所有组件"
    sh "$REPO/image/build_all.sh"
fi

echo ">>> 构建 live root + ISO"
INSTALLER_ARGS="sata0 --yes" INSTALLER_FINISH=shutdown \
    LIVEROOT="$WORK/liveroot" sh "$REPO/live/build_liveroot.sh"
OUT_ISO="$ISO" LIVEROOT="$WORK/liveroot" sh "$REPO/live/make_iso.sh"

echo ">>> 建立空目标盘"
VM_DISK="$DISK" VM_SIZE="${VM_SIZE:-5G}" sh "$REPO/vm/create_vm.sh"

echo ">>> 无头安装（零输入，最长 ${TIMEOUT}s）"
: > "$LOG"
env HEADLESS=1 QEMU_NO_REBOOT=1 QEMU_SERIAL="file:$LOG" \
    VM_DISK="$DISK" OUT_ISO="$ISO" sh "$REPO/vm/run_install.sh" >/dev/null 2>&1 &
QPID=$!

# 完成标记出现后给 QEMU 一点收尾时间；进程自行退出则直接结束。
if wait_for_log_pid "$LOG" "$TIMEOUT" "$QPID" \
        "installer: all steps complete." \
        "installer: shutting down" \
        "installer: rebooting"; then
    # 正常路径：finish=shutdown 应让 QEMU 自己退出；最多等 15s 兜底。
    _wait=0
    while [ "$_wait" -lt 15 ] && kill -0 "$QPID" 2>/dev/null; do
        sleep 1
        _wait=$((_wait + 1))
    done
    if kill -0 "$QPID" 2>/dev/null; then
        echo "WARNING: QEMU 在完成标记后仍未退出（关机/重启可能失败）"
    fi
fi
kill "$QPID" 2>/dev/null || true
wait "$QPID" 2>/dev/null || true
echo "QEMU 已结束"

echo ">>> 断言安装日志"
assert_log "$LOG" "Select target disk" "step 10 select disk"
assert_log "$LOG" "Create partition table" "step 20 partition"
assert_log "$LOG" "Format " "step 30 format"
assert_log "$LOG" "Mount target filesystems" "step 40 mount"
assert_log "$LOG" "Install packages" "step 50 packages"
assert_log "$LOG" "Generate fstab / boot.conf" "step 60 config"
assert_log "$LOG" "Overall verification" "step 80 verify"
assert_log "$LOG" "installer: all steps complete." "install complete"
assert_no_log "$LOG" "installer: step failed" "no step failed"
assert_no_log "$LOG" "auto mode: step failed" "no fail-fast triggered"

if ! summary "无头安装测试"; then
    echo
    echo "----- install.log 尾部 -----"
    tail -60 "$LOG"
    exit 1
fi

[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"
