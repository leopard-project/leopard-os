# PROJECT KNOWLEDGE BASE — LeopardOS

镜像组装仓库（非 gen_ninja 组件）：把内核 + 引导 + 各用户态组件 + 配置打包成可启动镜像。

## 脚本
- `build_liveroot.sh` — 构建 live root（XJPAK10 live 归档；xbps 包用 gzip 压缩，见下）。
- `make_iso.sh` — 生成 UEFI ISO（live 介质）。
- `img-tools/make_image.sh` — 一键全流程：先打包所有组件，再组装预装镜像。
- `img-tools/assemble_image.sh` — 纯组装：只消费各组件 `out/*.xbps`（不现场打包）。
- `img-tools/packages.conf` — 组件清单（单点真理：目录/构建脚本/包名）。
- `lib/qemu.sh` — QEMU 共用样板（`qemu_boot <disk> [iso]` + OVMF 探测）。
- `run_system.sh` / `run_install.sh` / `img-tools/run.sh` — QEMU 跑系统/安装器/预装镜像，均复用 `lib/qemu.sh`。
- `create_vm.sh` — 生成 VM 磁盘。
- `tools/makepak.py` — XJPAK10 live-root 打包。

## 组件清单（packages.conf）

镜像里的包由 `img-tools/packages.conf` 单点定义，格式 `<目录> <构建脚本> <包名>`。
新增/移除镜像组件只改这一份清单；`make_image.sh` 读前两列打包，`assemble_image.sh` 读
第 1、3 列收包并安装。注意 `leopard-xbps` 目录出的包名是 `xbps`（与目录名不同）。

## 关键事实
- 镜像组装：`dd` + `sgdisk -n 1:2048 -t 1:ef00` + `mkfs.vfat -F 32 --offset 2048` + `mcopy`。
- xbps 包/repodata 用 **gzip** 压缩（不是 zstd）——zstd 会触发上游内存 bug（见 OpenXSKernel AGENTS.md）。
- OVMF 用 `/usr/share/ovmf/OVMF.fd`（合并版），不要用 `OVMF_CODE_4M.fd` 直喂 `-bios`。
- 版本：OpenXSKernel v2.1.0、OpenXSBoot 2.1、其余 1.0。
