#!/bin/sh
set -eu

# LeopardOS 一键全流程：先打包所有组件，再组装镜像。
# 只想组装（包已预构建）直接跑 assemble_image.sh。
# 依赖：python3、ninja、xbps 工具（leopard-xbps/out）；组装依赖见 assemble_image.sh

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/../.."
XBP="$PROJ/leopard-xbps/out"
MANIFEST="$ROOT/packages.conf"

export PATH="$XBP:$PATH"

# 打包所有组件（读清单第 1、2 列）
while read -r dir script _pkg; do
    case "$dir" in ''|'#'*) continue ;; esac
    (cd "$PROJ/$dir" && python3 "$script" >/dev/null && ninja pack >/dev/null)
done < "$MANIFEST"

# 交给纯组装脚本
exec "$ROOT/assemble_image.sh"
