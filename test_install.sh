#!/bin/sh
set -eu

# 一键无头安装测试：空盘 -> live ISO -> 零输入自动安装 -> 断言串口日志。
# 环境变量：
#   BUILD=1        先打包所有组件（默认 0，假定已构建）
#   TIMEOUT=300    QEMU 超时秒数
#   WORK=路径       工作目录（默认 .testwork）
#   KEEP=1         保留工作目录（默认清理）

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK="${WORK:-$ROOT/.testwork}"
TIMEOUT="${TIMEOUT:-300}"
ISO="$WORK/leopard-installer.iso"
DISK="$WORK/target.vmdk"
LOG="$WORK/install.log"

. "$ROOT/lib/logcheck.sh"

rm -rf "$WORK"
mkdir -p "$WORK"

if [ "${BUILD:-0}" = "1" ]; then
    echo ">>> 打包所有组件"
    sh "$ROOT/img-tools/build_all.sh"
fi

echo ">>> 构建 live root + ISO"
INSTALLER_ARGS="sata0 --yes" LIVEROOT="$WORK/liveroot" sh "$ROOT/build_liveroot.sh"
OUT_ISO="$ISO" LIVEROOT="$WORK/liveroot" sh "$ROOT/make_iso.sh"

echo ">>> 建立空目标盘"
VM_DISK="$DISK" VM_SIZE=1G sh "$ROOT/create_vm.sh"

echo ">>> 无头安装（零输入，最长 ${TIMEOUT}s）"
: > "$LOG"
set +e
timeout "$TIMEOUT" env HEADLESS=1 QEMU_NO_REBOOT=1 QEMU_SERIAL="file:$LOG" \
    VM_DISK="$DISK" OUT_ISO="$ISO" sh "$ROOT/run_install.sh"
RC=$?
set -e
echo "QEMU 退出码: $RC"

echo ">>> 断言安装日志"
assert_log "$LOG" "Select target disk" "step 10 select disk"
assert_log "$LOG" "Create partition table" "step 20 partition"
assert_log "$LOG" "Format FAT32" "step 30 format"
assert_log "$LOG" "Mount target filesystems" "step 40 mount"
assert_log "$LOG" "Install packages" "step 50 packages"
assert_log "$LOG" "Generate fstab / boot.conf" "step 60 config"
assert_log "$LOG" "Overall verification" "step 80 verify"
assert_log "$LOG" "installer: all steps complete. rebooting..." "install complete"
assert_no_log "$LOG" "installer: step failed" "no step failed"
assert_no_log "$LOG" "auto mode: step failed" "no fail-fast triggered"

[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"
summary "无头安装测试"
