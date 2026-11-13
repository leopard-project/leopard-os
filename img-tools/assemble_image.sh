#!/bin/sh
set -eu

# LeopardOS 纯组装脚本：只消费各组件 out/*.xbps（预构建产物），不现场打包。
# 「包已打好」走这里；「包没打」先跑 make_image.sh（它打包后再调本脚本）。
# 依赖：xbps 工具（leopard-xbps/out）、dd、sgdisk(gdisk)、mkfs.vfat(dosfstools)、
#       mcopy(mtools)、qemu-img

ROOT=$(cd "$(dirname "$0")" && pwd)
PROJ="$ROOT/../.."
XBP="$PROJ/leopard-xbps/out"
MANIFEST="$ROOT/packages.conf"

IMAGE="$ROOT/XJ380.img"
STAGE="$ROOT/.stage"
REPO="$ROOT/.repo"
IMG_MIB=128

export PATH="$XBP:$PATH"

rm -rf "$REPO" "$STAGE"
mkdir -p "$REPO"

# 1. 从组件清单收包（第 1 列目录 -> 第 3 列包名）
PACKAGES=""
while read -r dir _script pkg; do
    case "$dir" in ''|'#'*) continue ;; esac
    find "$PROJ/$dir/out" -maxdepth 1 -name '*.xbps' -exec cp -t "$REPO" {} +
    PACKAGES="$PACKAGES $pkg"
done < "$MANIFEST"

# 2. 建本地仓库索引
xbps-rindex -a "$REPO"/*.xbps >/dev/null

# 3. 把包安装进 stage（pacstrap 风格）
xbps-install -y -r "$STAGE" -R "$REPO" $PACKAGES

# 4. 烤仓库进镜像（供 LeopardOS 内 xbps 后续装/卸）+ 写仓库配置
mkdir -p "$STAGE/system/repo" "$STAGE/config/xbps.d"
cp "$REPO"/* "$STAGE/system/repo/"
echo "repository=/system/repo" > "$STAGE/config/xbps.d/repo.conf"

# 5. 建裸盘 + GPT(ef00) + FAT32
rm -f "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMG_MIB" status=none
sgdisk "$IMAGE" -n 1:2048 -t 1:ef00 >/dev/null 2>&1
FAT_KIB=$(( (IMG_MIB - 1) * 1024 ))          # 扣掉 1MiB GPT 区
mkfs.vfat -F 32 --offset 2048 -S 512 "$IMAGE" "$FAT_KIB" >/dev/null 2>&1

# 6. 拷进 FAT 分区（@@ 后是分区起始字节偏移 = 2048*512）
mcopy -o -s -i "$IMAGE@@$((2048 * 512))" "$STAGE"/* ::

# 7. 转成 vmdk（测试平台虚拟磁盘格式）
VMDK="$ROOT/XJ380.vmdk"
rm -f "$VMDK"
qemu-img convert -f raw -O vmdk -o subformat=monolithicSparse "$IMAGE" "$VMDK"

rm -rf "$STAGE" "$REPO"
echo "镜像已生成: $IMAGE ($IMG_MIB MiB) -> $VMDK"
