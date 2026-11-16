#!/bin/sh
set -eu

# One-shot headless install test: empty disk -> live ISO -> zero-input auto install
# -> assert on the serial log.
#
# Optimizations:
#   - auto install uses finish=shutdown, so it powers off right away instead of
#     idling until TIMEOUT;
#   - stop QEMU early once a done/failed marker appears (wait_for_log), making
#     each run faster;
#   - on failure, automatically print the log tail for triage.
#
# Environment variables:
#   BUILD=1        pack all components first (default 0, assumes built)
#   TIMEOUT=300    max wait in seconds (early exit usually returns far sooner)
#   WORK=path      work directory (default .testwork)
#   KEEP=1         keep the work directory (default: clean up)

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
    sh "$REPO/build/build_all.sh"
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

# After the done marker appears, give QEMU a moment to wrap up; if the process exits on its own, end right away.
if wait_for_log_pid "$LOG" "$TIMEOUT" "$QPID" \
        "installer: all steps complete." \
        "installer: shutting down" \
        "installer: rebooting"; then
    # Happy path: finish=shutdown should make QEMU exit by itself; wait up to 15s as a fallback.
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
