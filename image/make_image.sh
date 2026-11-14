#!/bin/sh
set -eu

# LeopardOS 一键全流程：先打包所有组件（../build/build_all.sh），再组装镜像。

ROOT=$(cd "$(dirname "$0")" && pwd)

"$ROOT/../build/build_all.sh"
exec "$ROOT/assemble_image.sh"
