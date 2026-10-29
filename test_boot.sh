#!/bin/sh
set -eu

# 无头启动测试：引导已安装的盘，断言 rc -> getty -> OOBE。
# 系统会停在登录提示，由 timeout 结束（退出码 124 属正常）。
# 环境变量：WORK（默认 .testwork）/ TIMEOUT（默认 90）

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK="${WORK:-$ROOT/.testwork}"
TIMEOUT="${TIMEOUT:-90}"
DISK="$WORK/target.vmdk"
LOG="$WORK/boot.log"

. "$ROOT/lib/logcheck.sh"

[ -f "$DISK" ] || { echo "找不到已装系统盘: $DISK（先跑 test_install.sh，或设 WORK）" >&2; exit 1; }

echo ">>> 无头启动（最长 ${TIMEOUT}s；停在登录提示后由 timeout 结束属正常）"
: > "$LOG"
set +e
timeout "$TIMEOUT" env HEADLESS=1 QEMU_NO_REBOOT=1 QEMU_SERIAL="file:$LOG" \
    VM_DISK="$DISK" sh "$ROOT/run_system.sh"
RC=$?
set -e
echo "QEMU 退出码: $RC（124=超时，停在登录提示，正常）"

echo ">>> 断言启动日志"
assert_log "$LOG" "LeopardRC: init started" "rc 启动"
assert_log "$LOG" "LeopardGetty: console login" "getty 进入登录"
assert_log "$LOG" "Leopard OOBE: first boot setup" "首次启动进入 OOBE"

summary "无头启动测试"
