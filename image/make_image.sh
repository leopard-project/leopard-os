#!/bin/sh
set -eu

# LeopardOS one-shot flow: pack all components first (../build/build_all.sh), then assemble the image.

ROOT=$(cd "$(dirname "$0")" && pwd)

"$ROOT/../build/build_all.sh"
exec "$ROOT/assemble_image.sh"
