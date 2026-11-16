#!/bin/sh
set -eu

# Full end-to-end test: install (empty disk + ISO) → boot the installed disk.
# Environment: BUILD=0 (skip packing; default 1 packs first to avoid stale packages),
#              TIMEOUT (install timeout, default 300), WORK (default .testwork),
#              KEEP=1 (keep the work directory)
ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
WORK="${WORK:-$REPO/.testwork}"

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
