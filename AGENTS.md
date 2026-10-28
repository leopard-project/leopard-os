# PROJECT KNOWLEDGE BASE — LeopardOS

镜像组装仓库（非 gen_ninja 组件）：把内核 + 引导 + 各用户态组件 + 配置打包成可启动镜像。

## 脚本
- `build_liveroot.sh` — 构建 live root（XJPAK10 live 归档；xbps 包用 gzip 压缩，见下）。
- `make_iso.sh` — 生成 UEFI ISO（live 介质）。
- `run_system.sh` / `run_install.sh` — QEMU 跑系统/安装器。
- `create_vm.sh` — 生成 VM 磁盘。
- `tools/makepak.py` — XJPAK10 live-root 打包。

## 关键事实
- 镜像组装：`dd` + `sgdisk -n 1:2048 -t 1:ef00` + `mkfs.vfat -F 32 --offset 2048` + `mcopy`。
- xbps 包/repodata 用 **gzip** 压缩（不是 zstd）——zstd 会触发上游内存 bug（见 OpenXSKernel AGENTS.md）。
- OVMF 用 `/usr/share/ovmf/OVMF.fd`（合并版），不要用 `OVMF_CODE_4M.fd` 直喂 `-bios`。
- 版本：OpenXSKernel v2.1.0、OpenXSBoot 2.1、其余 1.0。
