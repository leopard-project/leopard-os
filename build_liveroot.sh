#!/bin/sh
set -eu

# 组装 live root（安装介质上的 live 环境，解到 RAM 跑 installer）
#   live 工具（解包版）+ initrc(尾端 installer) + /media(全部 xbps 包 + 索引)

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/.."
LIVEROOT="${LIVEROOT:-$ROOT/liveroot}"
MEDIA="$LIVEROOT/media"

rm -rf "$LIVEROOT"
mkdir -p "$LIVEROOT/system/leopard" "$LIVEROOT/system/config" "$LIVEROOT/config" "$LIVEROOT/apps/system" "$MEDIA"

# --- live 工具二进制（解包版，直接跑） ---
cp "$PROJ/leopard-rc/out/leopard-rc.elf"           "$LIVEROOT/system/leopard/leopard-rc.elf"
cp "$PROJ/leopard-installer/out/leopard-installer.elf" "$LIVEROOT/apps/system/leopard-installer.elf"
cp "$PROJ/leopard-disk/out/lpdisk.elf"             "$LIVEROOT/apps/system/lpdisk.elf"
cp "$PROJ/mkfs-fat32/out/mkfs-fat32.elf"           "$LIVEROOT/apps/system/mkfs-fat32.elf"
cp "$PROJ/leopard-ime/out/leopard-ime.elf"         "$LIVEROOT/apps/system/leopard-ime.elf"
for t in xbps-install xbps-query xbps-create xbps-rindex xbps-remove xbps-pkgdb; do
    cp "$PROJ/leopard-xbps/out/$t" "$LIVEROOT/apps/system/$t"
done

# --- live initrc：尾端跑 installer（不是 getty） ---
printf '# Leopard live 环境\nrespawn /apps/system/leopard-ime.elf\nrespawn /apps/system/leopard-installer.elf\n' > "$LIVEROOT/system/config/initrc"

# --- /media：全部 xbps 包 + 仓库索引 ---
find "$PROJ" -maxdepth 3 -name '*.xbps' -path '*/out/*' -exec cp {} "$MEDIA/" \;
"$PROJ/leopard-xbps/out/xbps-rindex" --compression gzip -a "$MEDIA"/*.xbps >/dev/null 2>&1

echo "live root 已组装: $LIVEROOT"
echo "  media 包数: $(ls "$MEDIA"/*.xbps 2>/dev/null | wc -l)"
