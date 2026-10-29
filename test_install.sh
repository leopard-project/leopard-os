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
assert_log "$LOG" "选择目标磁盘" "步骤 10 选择磁盘"
assert_log "$LOG" "建立分区表" "步骤 20 分区"
assert_log "$LOG" "格式化 FAT32" "步骤 30 格式化"
assert_log "$LOG" "挂载目标文件系统" "步骤 40 挂载"
assert_log "$LOG" "安装软件包" "步骤 50 装包"
assert_log "$LOG" "生成 fstab / boot.conf" "步骤 60 配置"
assert_log "$LOG" "整体校验" "步骤 80 校验"
assert_log "$LOG" "installer: all steps complete. rebooting..." "安装完成"
assert_no_log "$LOG" "installer: step failed" "无步骤失败"
assert_no_log "$LOG" "auto mode: step failed" "未触发 fail-fast"

[ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"
summary "无头安装测试"
