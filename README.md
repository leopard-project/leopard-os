# leopard-os

LeopardOS 镜像 / live 介质 / 测试组装仓库。

它不是内核或用户态组件仓库；它消费各组件 `out/*.xbps`，组装：

- 安装介质 ISO（最小 PE + `/media` 本地仓库）
- 预装磁盘镜像（modern 布局）
- QEMU 测试环境

## 目录

```
image/   预装镜像组装（build_all / assemble_image / make_image / packages.conf / run_image）
live/    最小 PE + ISO（build_liveroot / make_iso / pe.list / boot.conf / makepak.py）
tests/   无头测试（test_all / test_install / test_boot / test_cli）
vm/      空盘和 QEMU（create_vm / run_install / run_system）
lib/     共用库（qemu.sh / logcheck.sh）
docs/    操作手册（TESTING.md）
```

## 快速开始

先构建组件包（或使用已有的 `out/*.xbps`）：

```sh
sh image/build_all.sh
```

生成安装介质：

```sh
sh live/build_liveroot.sh
sh live/make_iso.sh
# → leopard-installer.iso
```

全链路无头测试：

```sh
sh tests/test_all.sh
# 已构建过组件，跳过重打包：
BUILD=0 sh tests/test_all.sh

# 登录 + CLI 测试（使用 test_all 的 WORK）
WORK=.testwork bash tests/test_cli.sh
```

生成预装镜像：

```sh
sh image/make_image.sh
# → image/XJ380.img / image/XJ380.vmdk
```

运行：

```sh
sh vm/run_install.sh   # ISO 安装
sh vm/run_system.sh    # 直接启动已装盘
sh image/run_image.sh  # 启动预装镜像
```

## 包来源

安装介质的 `/media` 来自 `../leopard-packages/hostdir/binpkgs`，由：

```sh
cd ../leopard-packages
./leopard-src sync
./leopard-src verify
```

生成。`live/build_liveroot.sh` 只按 `media.list` 取包，不会扫描各组件 `out/`。

## 文档

- `docs/TESTING.md` — 测试/安装操作手册
- `AGENTS.md` — 仓库结构、红线、关键事实
- `../leopard-packages/README.md` — 包仓库、签名、手动分发、发布流程
