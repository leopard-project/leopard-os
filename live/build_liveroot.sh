#!/bin/sh
set -eu

# 组装最小预安装环境（PE）和 /media 本地包仓库。
#
#   live/pe.list    → PE：只放安装目标系统之前就要用的文件
#   leopard-packages/media.list → /media：目标系统包，由 xbps 安装
#
# 不再扫描所有兄弟仓库的 out/：/media 只从
# leopard-packages/hostdir/binpkgs 取包，避免旧包/废弃包混入介质。

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
PROJ=$(cd "$REPO/.." && pwd)
LIVEROOT="${LIVEROOT:-$REPO/liveroot}"
MEDIA="$LIVEROOT/media"
PE_LIST="$ROOT/pe.list"
PKG_DIR="$PROJ/leopard-packages"
BINPKGS="${LEOPARD_BINPKGS:-$PKG_DIR/hostdir/binpkgs}"

die() {
        echo "build_liveroot: $*" >&2
        exit 1
}

# --- 1. 准备受控的本地仓库 ------------------------------------------------
if [ "${LEOPARD_SYNC:-1}" = "1" ]; then
        [ -x "$PKG_DIR/leopard-src" ] || die "missing $PKG_DIR/leopard-src"
        sh "$PKG_DIR/leopard-src" sync
fi

[ -f "$PE_LIST" ] || die "missing PE list: $PE_LIST"
[ -f "$PKG_DIR/media.list" ] || die "missing media list: $PKG_DIR/media.list"
[ -d "$BINPKGS" ] || die "missing package repo: $BINPKGS (run leopard-src sync)"
[ -f "$BINPKGS/x86_64-repodata" ] || die "missing $BINPKGS/x86_64-repodata"

rm -rf "$LIVEROOT"
mkdir -p "$LIVEROOT/system/leopard" "$LIVEROOT/system/config" "$LIVEROOT/config" \
         "$LIVEROOT/apps/system" "$MEDIA"

# --- 2. 最小 PE -----------------------------------------------------------
copy_pe() {
        while read -r src dst; do
                case "$src" in
                        ''|'#'*) continue ;;
                esac
                [ -n "${dst:-}" ] || die "pe.list: missing destination for $src"

                case "$src" in
                        *"*"*)
                                mkdir -p "$LIVEROOT/$dst"
                                cp $PROJ/$src "$LIVEROOT/$dst/"
                                ;;
                        *)
                                mkdir -p "$LIVEROOT/$(dirname "$dst")"
                                cp "$PROJ/$src" "$LIVEROOT/$dst"
                                ;;
                esac
        done < "$PE_LIST"
}
copy_pe

# 安装选项：无头自动安装写 auto=1，否则用默认交互配置
if [ -n "${INSTALLER_ARGS:-}" ]; then
        # 从 INSTALLER_ARGS 取目标盘（如 'sata0 --yes'）
        set -- $INSTALLER_ARGS
        profile="${INSTALLER_PROFILE:-modern}"
        printf 'auto=1\ndisk=%s\nprofile=%s\nscheme=%s\nfinish=%s\n' "${1:-sata0}" "$profile" "$profile" "${INSTALLER_FINISH:-reboot}" > "$LIVEROOT/config/leopard-install.conf"
        if [ -n "${INSTALLER_MODULES:-}" ]; then
                printf 'modules=%s\n' "$INSTALLER_MODULES" >> "$LIVEROOT/config/leopard-install.conf"
        fi
        if [ -n "${INSTALLER_PACKAGE_PROFILE:-}" ]; then
                printf 'package_profile=%s\n' "$INSTALLER_PACKAGE_PROFILE" >> "$LIVEROOT/config/leopard-install.conf"
        fi
else
        cp "$PROJ/leopard-installer/data/leopard-install.conf" "$LIVEROOT/config/leopard-install.conf"
fi

# live initrc：尾端跑 installer（不是 getty）
# 编排器不解析 argv；auto/disk 等选项走 /config/leopard-install.conf
printf '# Leopard live 环境\nrespawn /apps/system/leopard-installer.elf\n' > "$LIVEROOT/system/config/initrc"

# --- 3. /media：只包含 media.list 的包 + 索引 -----------------------------
copy_media() {
        count=0
        for pkg in $(sh "$PKG_DIR/leopard-src" list); do
                n=0
                for f in "$BINPKGS/$pkg"-*.xbps; do
                        [ -f "$f" ] && n=$((n + 1))
                done
                [ "$n" -eq 1 ] || die "media repo must contain exactly one build of $pkg (found $n)"
                cp "$BINPKGS/$pkg"-*.xbps "$MEDIA/"
                count=$((count + 1))
        done
        [ "$count" -gt 0 ] || die "media.list is empty"
        cp "$BINPKGS/x86_64-repodata" "$MEDIA/"
        echo "  media packages: $count"
}
copy_media

echo "live root 已组装: $LIVEROOT"
echo "  PE 文件数: $(find "$LIVEROOT" -path "$MEDIA" -prune -o -type f -print | wc -l)"
echo "  media 包数: $(ls "$MEDIA"/*.xbps 2>/dev/null | wc -l)"
