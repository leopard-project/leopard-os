#!/bin/sh
set -eu

# 一键全链路测试：安装（空盘 + ISO）→ 引导装好的盘。
# 环境变量：BUILD=0（跳过打包，默认 1 会先打包避免旧包）、TIMEOUT（安装超时，默认 300）、
#           WORK（默认 .testwork）、KEEP=1（保留工作目录）
ROOT=$(cd "$(dirname "$0")" && pwd)
WORK="${WORK:-$ROOT/.testwork}"

echo "===== 1/2 无头安装 ====="
BUILD="${BUILD:-1}" WORK="$WORK" TIMEOUT="${TIMEOUT:-300}" KEEP=1 \
    sh "$ROOT/test_install.sh"

echo
echo "===== 2/2 无头启动 ====="
WORK="$WORK" TIMEOUT="${BOOT_TIMEOUT:-60}" sh "$ROOT/test_boot.sh"

if [ "${KEEP:-0}" != "1" ]; then
    rm -rf "$WORK"
fi
echo
echo "全链路测试通过"
