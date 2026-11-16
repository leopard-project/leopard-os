#!/bin/sh
set -eu

# Assemble the minimal preinstall environment (PE) and the /media local package repo.
#
#   live/pe.list    → PE: only files needed before installing the target system
#   leopard-packages/media.list → /media: target system packages, installed by xbps
#
# No longer scans the out/ of every sibling repo: /media takes packages only
# from leopard-packages/hostdir/binpkgs, so stale/abandoned packages never
# leak into the media.

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

# --- 1. Prepare the controlled local repository ---------------------------
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

# --- 2. Minimal PE --------------------------------------------------------
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

# The .elf / xbps tools in the PE must be executable. The source tree mode can
# be lost during archiving/copying; fix it here uniformly and hard-check before
# leaving, so we never produce a "Not Executable" initrd.
ensure_pe_modes() {
        find "$LIVEROOT/apps" "$LIVEROOT/system" -type f -name '*.elf' \
                -exec chmod 0755 {} + 2>/dev/null || true
        for f in "$LIVEROOT"/apps/system/xbps-*; do
                [ -e "$f" ] && chmod 0755 "$f"
        done

        for f in \
                "$LIVEROOT/system/leopard/leopard-rc.elf" \
                "$LIVEROOT/apps/leopard/leopard-conhost.elf" \
                "$LIVEROOT/apps/system/leopard-installer.elf"; do
                [ -f "$f" ] || die "missing PE executable: $f"
                [ -x "$f" ] || die "PE file is not executable: $f"
        done
}
ensure_pe_modes

# Install options: headless auto install writes auto=1, else use the default interactive config
if [ -n "${INSTALLER_ARGS:-}" ]; then
        # take the target disk from INSTALLER_ARGS (e.g. 'sata0 --yes')
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

# live initrc: conhost owns the console/VT and runs the installer on a PTY
# The orchestrator does not parse argv; auto/disk etc. come from /config/leopard-install.conf
printf '# Leopard live 环境\nrespawn /apps/leopard/leopard-conhost.elf /apps/system/leopard-installer.elf\n' > "$LIVEROOT/system/config/initrc"

# --- 3. /media: only the packages in media.list + index -------------------
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
