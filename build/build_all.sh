#!/bin/sh
set -eu

# Pack all components (kernel/bootloader/userland) from packages.conf to prepare
# artifacts before assembling an image or running tests.
# Pack only, no assembly. See assemble_image.sh for assembly.

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/../.."
XBP="$PROJ/leopard-xbps/out"
MANIFEST="$ROOT/packages.conf"

export PATH="$XBP:$PATH"

# The SDK builds runtime, the full XACT CRT and the xact-crt package
# (liballoc comes from the submodule).
echo ">>> build XJ380-SDK + XACT CRT"
(cd "$PROJ/XJ380-SDK" && git submodule update --init --recursive >/dev/null 2>&1 || true; python3 tools/gen_ninja.py >/dev/null && ninja >/dev/null && ninja pack >/dev/null)

while read -r dir script _pkg; do
    case "$dir" in ''|'#'*) continue ;; esac
    echo ">>> pack $dir"
    (cd "$PROJ/$dir" && python3 "$script" >/dev/null && ninja pack >/dev/null)
    # In-tree kernel modules: build their separate packages when available.
    if grep -q "build pack-kmods:" "$PROJ/$dir/build.ninja" 2>/dev/null; then
        (cd "$PROJ/$dir" && ninja pack-kmods >/dev/null)
    fi
done < "$MANIFEST"

# The installer is not in packages.conf (it only goes into the live ISO, not the
# target system), but live/build_liveroot.sh takes its out/*.elf directly, so
# refresh it here as well.
echo ">>> build leopard-installer"
(cd "$PROJ/leopard-installer" && python3 gen_ninja.py >/dev/null && ninja build >/dev/null && ninja pack >/dev/null)

echo "全部组件打包完成"
