#!/bin/sh
set -eu

# 从 packages.conf 打包全部组件（内核/引导/用户态），供组装镜像或测试前准备产物。
# 只打包，不组装。组装见 assemble_image.sh。

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/../.."
XBP="$PROJ/leopard-xbps/out"
MANIFEST="$ROOT/packages.conf"

export PATH="$XBP:$PATH"

# SDK 同时构建 runtime、完整 XACT CRT 和 xact-crt 包（liballoc 来自 submodule）。
echo ">>> build XJ380-SDK + XACT CRT"
(cd "$PROJ/XJ380-SDK" && git submodule update --init --recursive >/dev/null 2>&1 || true; python3 tools/gen_ninja.py >/dev/null && ninja >/dev/null && ninja pack >/dev/null)

while read -r dir script _pkg; do
    case "$dir" in ''|'#'*) continue ;; esac
    echo ">>> pack $dir"
    (cd "$PROJ/$dir" && python3 "$script" >/dev/null && ninja pack >/dev/null)
done < "$MANIFEST"

# 安装器不在 packages.conf（它只进 live ISO，不装进目标系统），
# 但 build_liveroot.sh 直接取它的 out/*.elf，所以这里也要刷新。
echo ">>> build leopard-installer"
(cd "$PROJ/leopard-installer" && python3 gen_ninja.py >/dev/null && ninja build >/dev/null && ninja pack >/dev/null)

echo "全部组件打包完成"
