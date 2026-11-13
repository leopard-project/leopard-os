#!/bin/sh
set -eu

# 无头启动测试：引导已安装的盘，断言 rc -> getty -> OOBE。
#
# 优化点：日志出现 OOBE/登录提示后主动结束 QEMU，不再空等 TIMEOUT。
# 环境变量：WORK（默认 .testwork）/ TIMEOUT（默认 60）

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK="${WORK:-$ROOT/.testwork}"
TIMEOUT="${TIMEOUT:-60}"
DISK="$WORK/target.vmdk"
LOG="$WORK/boot.log"

. "$ROOT/lib/logcheck.sh"

[ -f "$DISK" ] || { echo "找不到已装系统盘: $DISK（先跑 test_install.sh，或设 WORK）" >&2; exit 1; }

echo ">>> 无头启动（最长 ${TIMEOUT}s；出现登录/OOBE 后自动结束）"
: > "$LOG"
env HEADLESS=1 QEMU_NO_REBOOT=1 QEMU_SERIAL="file:$LOG" \
    VM_DISK="$DISK" sh "$ROOT/run_system.sh" >/dev/null 2>&1 &
QPID=$!

if wait_for_log_pid "$LOG" "$TIMEOUT" "$QPID" \
        "LeopardGetty: console login" \
        "Leopard OOBE: first boot setup"; then
    sleep 1
fi
kill "$QPID" 2>/dev/null || true
wait "$QPID" 2>/dev/null || true
echo "QEMU 已结束"

echo ">>> 断言启动日志"
assert_log "$LOG" "LeopardRC: init started" "rc 启动"
assert_log "$LOG" "LeopardGetty: console login" "getty 进入登录"
assert_log "$LOG" "Leopard OOBE: first boot setup" "首次启动进入 OOBE"

if ! summary "无头启动测试"; then
    echo
    echo "----- boot.log 尾部 -----"
    tail -60 "$LOG"
    exit 1
fi
