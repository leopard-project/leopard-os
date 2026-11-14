#!/bin/sh
set -eu

# LeopardOS 一键全流程：先打包所有组件（build_all.sh），再组装镜像（assemble_image.sh）。
# 只想组装（包已预构建）直接跑 assemble_image.sh。

ROOT=$(cd "$(dirname "$0")" && pwd)

"$ROOT/build_all.sh"
exec "$ROOT/assemble_image.sh"
