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
cp "$PROJ/leopard-utils/out/lpdisk.elf"            "$LIVEROOT/apps/system/lpdisk.elf"
cp "$PROJ/leopard-utils/out/mkfs-fat32.elf"        "$LIVEROOT/apps/system/mkfs-fat32.elf"
cp "$PROJ/leopard-utils/out/mkfs-ext4.elf"         "$LIVEROOT/apps/system/mkfs-ext4.elf"
for t in xbps-install xbps-query xbps-create xbps-rindex xbps-remove xbps-pkgdb; do
    cp "$PROJ/leopard-xbps/out/$t" "$LIVEROOT/apps/system/$t"
done

# --- live 安装器：步骤程序 + 配置（编排器读 /config/leopard-install-*.conf） ---
mkdir -p "$LIVEROOT/apps/leopard/installer/steps"
cp "$PROJ/leopard-installer/out/steps/"*.elf "$LIVEROOT/apps/leopard/installer/steps/"
cp "$PROJ/leopard-installer/data/leopard-install-sequence.conf" "$LIVEROOT/config/leopard-install-sequence.conf"
if [ -n "${INSTALLER_ARGS:-}" ]; then
    # 无头自动安装：从 INSTALLER_ARGS 取目标盘（如 'sata0 --yes'），写 auto 配置
    set -- $INSTALLER_ARGS
    printf 'auto=1\ndisk=%s\nscheme=ext4\nfinish=%s\n' "${1:-sata0}" "${INSTALLER_FINISH:-reboot}" > "$LIVEROOT/config/leopard-install.conf"
else
    cp "$PROJ/leopard-installer/data/leopard-install.conf" "$LIVEROOT/config/leopard-install.conf"
fi

# --- live initrc：尾端跑 installer（不是 getty） ---
# 编排器不解析 argv；auto/disk 等选项走 /config/leopard-install.conf
printf '# Leopard live 环境\nrespawn /apps/system/leopard-installer.elf\n' > "$LIVEROOT/system/config/initrc"

# --- /media：全部 xbps 包 + 仓库索引 ---
find "$PROJ" -maxdepth 3 -name '*.xbps' -path '*/out/*' -exec cp {} "$MEDIA/" \;
"$PROJ/leopard-xbps/out/xbps-rindex" --compression gzip -a "$MEDIA"/*.xbps >/dev/null 2>&1

echo "live root 已组装: $LIVEROOT"
echo "  media 包数: $(ls "$MEDIA"/*.xbps 2>/dev/null | wc -l)"
