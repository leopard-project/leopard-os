#!/bin/sh
set -eu

# Interactive TUI install test.
#
# Boots the installer ISO without auto=1, so the installer starts in TUI mode.
# The screen is conhost's VT; there is no need for a graphical display because
# we drive the emulated PS/2 keyboard through QEMU's HMP monitor and observe
# the serial log:
#
#   welcome -> disk menu -> erase confirm -> install profile
#           -> package profile -> package confirm -> progress -> finish menu
#
# Environment: WORK, TIMEOUT (default 600), KEEP=1.
# Requires qemu-system-x86_64 with a monitor socket and socat.

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
WORK="${WORK:-$REPO/.testwork-tui}"
TIMEOUT="${TIMEOUT:-600}"
ISO="$WORK/leopard-installer.iso"
DISK="$WORK/target.vmdk"
LOG="$WORK/install.log"
MON="$WORK/monitor.sock"
MONIN="$WORK/monitor.in"
MONOUT="$WORK/monitor.out"
QPID=""
SPID=""

. "$REPO/lib/logcheck.sh"

cleanup() {
    exec 3>&- 2>/dev/null || true
    [ -n "$SPID" ] && kill "$SPID" 2>/dev/null || true
    [ -n "$QPID" ] && kill "$QPID" 2>/dev/null || true
    wait "$SPID" 2>/dev/null || true
    wait "$QPID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

fail() {
    echo "TUI 测试失败: $*" >&2
    echo "----- 串口日志尾部 -----" >&2
    tail -80 "$LOG" 2>/dev/null >&2 || true
    echo "----- monitor -----" >&2
    tail -40 "$MONOUT" 2>/dev/null >&2 || true
    exit 1
}

key() {
    printf 'sendkey %s\n' "$1" >&3
    sleep 0.5
}

rm -rf "$WORK"
mkdir -p "$WORK"

echo ">>> 构建 live root（交互模式，不写 auto=1）"
LIVEROOT="$WORK/liveroot" LEOPARD_SYNC="${LEOPARD_SYNC:-1}" \
    sh "$REPO/live/build_liveroot.sh"
OUT_ISO="$ISO" LIVEROOT="$WORK/liveroot" sh "$REPO/live/make_iso.sh"

echo ">>> 建立空目标盘"
VM_DISK="$DISK" VM_SIZE="${VM_SIZE:-5G}" sh "$REPO/vm/create_vm.sh"

echo ">>> 启动 TUI 安装（QEMU monitor: $MON）"
: > "$LOG"
env HEADLESS=1 QEMU_NO_REBOOT=1 QEMU_SERIAL="file:$LOG" \
    QEMU_MONITOR="unix:$MON,server=on,wait=off" \
    VM_DISK="$DISK" OUT_ISO="$ISO" \
    sh "$REPO/vm/run_install.sh" >/dev/null 2>&1 &
QPID=$!

# Wait for the monitor socket, then attach a single long-lived HMP client.
_n=0
while [ ! -S "$MON" ] && [ "$_n" -lt 300 ]; do
    kill -0 "$QPID" 2>/dev/null || fail "QEMU 提前退出"
    sleep 0.1
    _n=$((_n + 1))
done
[ -S "$MON" ] || fail "monitor socket 未出现"

mkfifo "$MONIN"
socat - UNIX-CONNECT:"$MON" <"$MONIN" >"$MONOUT" 2>&1 &
SPID=$!
exec 3>"$MONIN"

wait_for_log "$LOG" 180 "installer: TUI mode" || fail "未进入 TUI 模式"
wait_for_log "$LOG" 60 "installer: ui welcome" || fail "欢迎界面未出现"
sleep 1
key down                                 # probe: move to Shut down
key up                                   # probe: back to Begin
key ret                                  # welcome: Begin installation

wait_for_log "$LOG" 60 "installer: ui menu Select target disk" || fail "磁盘菜单未出现"
sleep 1
key ret                                  # disk: first disk (sata0)

wait_for_log "$LOG" 60 "target disk: /dev/sata0" || fail "未选中 sata0"
wait_for_log "$LOG" 30 "installer: ui confirm All data on this disk" || fail "清盘确认未出现"
sleep 1
key up                                   # destructive confirm: No -> Yes
key ret

wait_for_log "$LOG" 60 "installer: ui menu Installation profile" || fail "安装方案菜单未出现"
sleep 1
key ret                                  # profile: modern

wait_for_log "$LOG" 120 "Create partition table" || fail "未到分区步骤"
wait_for_log "$LOG" 60 "installer: ui confirm Write this partition table?" || fail "分区确认未出现"
sleep 1
key ret                                  # write partition table: Yes
wait_for_log "$LOG" 180 "Format " || fail "未到格式化步骤"
wait_for_log "$LOG" 180 "Mount target filesystems" || fail "未到挂载步骤"

wait_for_log "$LOG" 180 "installer: ui menu Package profile" || fail "软件方案菜单未出现"
sleep 1
key ret                                  # package profile: standard

wait_for_log "$LOG" 60 "core packages:" || fail "软件方案未解析"
wait_for_log "$LOG" 30 "installer: ui confirm Install this software selection?" || fail "软件确认未出现"
sleep 1
key ret                                  # confirm software selection: Yes

wait_for_log "$LOG" 420 "installer: all steps complete." || fail "安装未完成"
wait_for_log "$LOG" 30 "installer: ui finish" || fail "完成菜单未出现"
sleep 1
key ret                                  # finish: Reboot (default)

wait_for_log "$LOG" 60 "installer: rebooting" || fail "未执行重启"

_n=0
while [ "$_n" -lt 20 ] && kill -0 "$QPID" 2>/dev/null; do
    sleep 1
    _n=$((_n + 1))
done
kill "$QPID" 2>/dev/null || true
wait "$QPID" 2>/dev/null || true
QPID=""

echo ">>> 断言 TUI 安装日志"
assert_log "$LOG" "installer: TUI mode (11 steps)" "TUI 模式启动"
assert_log "$LOG" "Select target disk" "step 10 disk menu"
assert_log "$LOG" "target disk: /dev/sata0" "disk selected"
assert_log "$LOG" "Resolve install plan" "step 15 plan menu"
assert_log "$LOG" "Create partition table" "step 20 partition"
assert_log "$LOG" "Format " "step 30 format"
assert_log "$LOG" "Mount target filesystems" "step 40 mount"
assert_log "$LOG" "Select optional software" "step 45 package menu"
assert_log "$LOG" "core packages:" "package selection resolved"
assert_log "$LOG" "Install packages" "step 50 packages"
assert_log "$LOG" "Generate fstab / boot.conf" "step 60 config"
assert_log "$LOG" "Overall verification" "step 80 verify"
assert_log "$LOG" "installer: all steps complete." "install complete"
assert_log "$LOG" "installer: rebooting" "finish action"
assert_no_log "$LOG" "installer: step failed" "no step failed"
assert_no_log "$LOG" "TUI unavailable" "lpcurses started"

if ! summary "TUI 安装测试"; then
    echo
    echo "----- install.log 尾部 -----"
    tail -80 "$LOG"
    exit 1
fi

[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"
