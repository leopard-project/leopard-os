#!/bin/sh
set -eu

# LeopardOS：用 xbps 把包"安装"到 stage 目录，再组装 FAT 镜像（pacstrap 风格）
# 依赖：python3、ninja、xbps 工具（leopard-xbps/out）、dd、sgdisk(gdisk)、
#       mkfs.vfat(dosfstools)、mcopy(mtools)；内核/引导各需其工具链

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/.."
XBP="$PROJ/leopard-xbps/out"

IMAGE="$ROOT/XJ380.img"
STAGE="$ROOT/.stage"
REPO="$ROOT/.repo"
IMG_MIB=128

export PATH="$XBP:$PATH"

# pack <dir> <gen_script>：生成 build.ninja → ninja pack 出包 → 收进仓库
pack() {
    (cd "$PROJ/$1" && python3 "$2" >/dev/null && ninja pack >/dev/null)
    find "$PROJ/$1/out" -name '*.xbps' -exec cp {} "$REPO/" \;
}

rm -rf "$REPO" "$STAGE"
mkdir -p "$REPO"

# 1. 打包所有组件（内核/引导的 gen_ninja.py 在 tools/ 下）
pack OpenXSBoot      tools/gen_ninja.py
pack OpenXSKernel    tools/gen_ninja.py
pack leopard-base    gen_ninja.py
pack leopard-rc      gen_ninja.py
pack leopard-getty   gen_ninja.py
pack leopard-oobe    gen_ninja.py
pack leopard-shell   gen_ninja.py
pack poweroff        gen_ninja.py
pack initctl         gen_ninja.py
pack leopard-mountd  gen_ninja.py
pack leopard-disk    gen_ninja.py
pack mkfs-fat32      gen_ninja.py
pack leopard-xbps    gen_ninja.py

# 2. 建本地仓库索引
xbps-rindex -a "$REPO"/*.xbps >/dev/null

# 3. 把包安装进 stage（pacstrap 风格）
xbps-install -y -r "$STAGE" -R "$REPO" \
    OpenXSBoot OpenXSKernel leopard-base leopard-rc leopard-getty \
    leopard-oobe leopard-shell poweroff initctl leopard-mountd leopard-disk mkfs-fat32 xbps

# 烤仓库进镜像（供 LeopardOS 内 xbps 后续装/卸）+ 写仓库配置
mkdir -p "$STAGE/system/repo" "$STAGE/system/etc/xbps.d"
cp "$REPO"/* "$STAGE/system/repo/"
echo "repository=/system/repo" > "$STAGE/system/etc/xbps.d/repo.conf"

# 4. 建裸盘 + GPT(ef00) + FAT32
rm -f "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMG_MIB" status=none
sgdisk "$IMAGE" -n 1:2048 -t 1:ef00 >/dev/null 2>&1
FAT_KIB=$(( (IMG_MIB - 1) * 1024 ))          # 扣掉 1MiB GPT 区
mkfs.vfat -F 32 --offset 2048 -S 512 "$IMAGE" "$FAT_KIB" >/dev/null 2>&1

# 5. 拷进 FAT 分区（@@后是分区起始字节偏移 = 2048*512）
mcopy -o -s -i "$IMAGE@@$((2048 * 512))" "$STAGE"/* ::

rm -rf "$STAGE" "$REPO"
echo "镜像已生成: $IMAGE ($IMG_MIB MiB)"
