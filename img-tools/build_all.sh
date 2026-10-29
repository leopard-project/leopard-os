#!/bin/sh
set -eu

# 从 packages.conf 打包全部组件（内核/引导/用户态），供组装镜像或测试前准备产物。
# 只打包，不组装。组装见 assemble_image.sh。

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/../.."
XBP="$PROJ/leopard-xbps/out"
MANIFEST="$ROOT/packages.conf"

export PATH="$XBP:$PATH"

while read -r dir script _pkg; do
    case "$dir" in ''|'#'*) continue ;; esac
    echo ">>> pack $dir"
    (cd "$PROJ/$dir" && python3 "$script" >/dev/null && ninja pack >/dev/null)
done < "$MANIFEST"

echo "全部组件打包完成"
