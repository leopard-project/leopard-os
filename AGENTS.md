# PROJECT KNOWLEDGE BASE — LeopardOS

镜像组装仓库（非 gen_ninja 组件）：把内核 + 引导 + 各用户态组件 + 配置打包成可启动镜像。

## 脚本
- `build_liveroot.sh` — 构建 live root（XJPAK10 live 归档；xbps 包用 gzip 压缩，见下）。
- `make_iso.sh` — 生成 UEFI ISO（live 介质）。
- `img-tools/make_image.sh` — 一键全流程：先打包所有组件，再组装预装镜像。
- `img-tools/assemble_image.sh` — 纯组装：只消费各组件 `out/*.xbps`（不现场打包）。
- `img-tools/build_all.sh` — 按 packages.conf 打包全部组件（只打包，不组装）。
- `img-tools/packages.conf` — 组件清单（单点真理：目录/构建脚本/包名）。
- `lib/qemu.sh` — QEMU 共用样板（`qemu_boot <disk> [iso]` + OVMF 探测）。参考官方内测指南：
  `QEMU_ACCEL=auto`（有 /dev/kvm 自动 KVM + `-cpu host`）、`QEMU_MEM`/`QEMU_SMP`、
  `QEMU_DISK_BUS=sata|nvme`、`QEMU_NET=1`（e1000 + hostfwd 2323）、`QEMU_AUDIO=1`、
  `QEMU_USB=1`（xHCI/USB 键鼠，Leopard 默认走 PS/2）、
  `QEMU_GDB=1`/`QEMU_PAUSE=1`、`QEMU_NO_REBOOT=1`、`QEMU_SERIAL`。
- `lib/logcheck.sh` — 测试日志断言库（`assert_log` / `assert_no_log` / `summary`）。
- `test_install.sh` — 一键无头安装测试（空盘→ISO→零输入自动安装→断言串口日志；
  完成/失败标记出现后提前结束 QEMU，auto 用 `finish=shutdown`）。
- `test_boot.sh` — 无头启动测试（断言 rc→getty→OOBE；出现登录/OOBE 后自动结束）。
- `test_all.sh` — 安装 + 启动全链路（共用 WORK；失败打印日志尾部）。
- `run_system.sh` / `run_install.sh` / `img-tools/run.sh` — QEMU 跑系统/安装器/预装镜像，均复用 `lib/qemu.sh`。
- `create_vm.sh` — 生成 VM 磁盘。
- `tools/makepak.py` — XJPAK10 live-root 打包。

## 组件清单（packages.conf）

镜像里的包由 `img-tools/packages.conf` 单点定义，格式 `<目录> <构建脚本> <包名>`。
新增/移除镜像组件只改这一份清单；`make_image.sh` 读前两列打包，`assemble_image.sh` 读
第 1、3 列收包并安装。注意 `leopard-xbps` 目录出的包名是 `xbps`（与目录名不同）。

## 关键事实
- 预装镜像（modern，默认 5 GiB）：GPT = ESP 64 MiB FAT32 + ext4 root + ext4 /users；
  root/users 用 `mkfs.ext4 -d` 直接铺 `.stage`，ESP 写 `BOOTX64.EFI`、`kernel.krl`、
  `boot.conf`、`EFI/XJ380/root.bin`。
- live ISO：live-root.img 解到 tmpfs，安装器再做现代布局。
- xbps 包/repodata 用 **gzip** 压缩（不是 zstd）——zstd 会触发上游内存 bug（见 OpenXSKernel AGENTS.md）。
- OVMF 用 `/usr/share/ovmf/OVMF.fd`（合并版），不要用 `OVMF_CODE_4M.fd` 直喂 `-bios`。
- 版本：OpenXSKernel v2.1.0、OpenXSBoot 2.1、其余 1.0。
