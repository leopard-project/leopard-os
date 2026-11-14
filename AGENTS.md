# PROJECT KNOWLEDGE BASE — LeopardOS

镜像组装仓库（非 gen_ninja 组件）：把内核 + 引导 + 各用户态组件 + 配置打包成可启动镜像。

## 目录 / 脚本

```
image/      预装镜像（build_all / assemble_image / make_image / packages.conf / run_image）
live/       最小 PE + ISO（build_liveroot / make_iso / pe.list / boot.conf / makepak.py）
tests/      无头测试（test_all / test_install / test_boot / test_cli）
vm/         空盘与 QEMU（create_vm / run_install / run_system）
lib/        共用库（qemu.sh / logcheck.sh）
docs/       操作手册（TESTING.md）
```

- `live/build_liveroot.sh` — 构建最小 PE + `/media` 本地仓库；PE 文件来自 `live/pe.list`，
  `/media` 只从 `../leopard-packages/hostdir/binpkgs` 按 `media.list` 取包
  （不再扫描各组件 `out/`）。
- `live/pe.list` — PE 清单：`<相对项目根路径> <相对 live root 目标路径>`；
  只放安装前需要的安装器/工具/配置，不放目标用户态。
- `../leopard-packages/leopard-src` — 受控仓库入口：`sync` 从组件 `out/` 取每个包
  最新的一份重建 `hostdir/binpkgs`；`repo` 重建/清理 repodata；`list` 打印 media 清单。
- `live/make_iso.sh` — 生成 UEFI ISO（live 介质）。
- `image/make_image.sh` — 一键全流程：先打包所有组件，再组装预装镜像。
- `image/assemble_image.sh` — 纯组装：只消费各组件 `out/*.xbps`（不现场打包）。
- `image/build_all.sh` — 按 `image/packages.conf` 打包全部组件（只打包，不组装）。
- `image/packages.conf` — 预装镜像组件清单（目录/构建脚本/包名）。
- `lib/qemu.sh` — QEMU 共用样板（`qemu_boot <disk> [iso]` + OVMF 探测）。
- `lib/logcheck.sh` — 测试日志断言库（`assert_log` / `assert_no_log` / `summary`）。
- `tests/test_install.sh` — 空盘→ISO→零输入自动安装→断言串口日志。
- `tests/test_boot.sh` — 无头启动测试（rc→getty→OOBE）。
- `tests/test_all.sh` — 安装 + 启动全链路（共用 WORK）。
- `tests/test_cli.sh` — OOBE 建号→登录→跑 CLI→poweroff。
- `vm/run_system.sh` / `vm/run_install.sh` / `image/run_image.sh` — QEMU 跑系统/安装器/预装镜像。
- `vm/create_vm.sh` — 生成 VM 磁盘。
- `live/makepak.py` — XJPAK10 live-root 打包。

## 组件清单（packages.conf / media.list）

- 安装介质 `/media` 的包清单在 `../leopard-packages/media.list`；由
  `leopard-src sync` 生成受控仓库，`live/build_liveroot.sh` 只消费它。
- 预装镜像的组件清单仍是 `image/packages.conf`，格式 `<目录> <构建脚本> <包名>`。
  `image/make_image.sh` 读前两列打包，`image/assemble_image.sh` 读第 1、3 列收包并安装。
- PE-only 包（`leopard-installer`、`xbps-create`、`xbps-rindex`）不得进入
  `media.list`；目标用户态包不得进入 `live/pe.list`。
- 注意 `leopard-xbps` 目录出的包名是 `xbps`（与目录名不同）。

## 关键事实
- 预装镜像（modern，默认 5 GiB）：GPT = ESP 64 MiB FAT32 + ext4 root + ext4 /users；
  root/users 用 `mkfs.ext4 -d` 直接铺 `.stage`，ESP 写 `BOOTX64.EFI`、`kernel.krl`、
  `boot.conf`、`EFI/XJ380/root.bin`。
- live ISO：live-root.img 解到 tmpfs，安装器再做现代布局。当前 `/media` 仍在
  live-root.img 内（会随 PE 一起进 RAM）；真正的“介质上的 /media”需要把 media
  镜像从 live-root.img 拆出去，并在引导器/内核侧提供访问方式，尚未实现。
- xbps 包/repodata 用 **gzip** 压缩（不是 zstd）——zstd 会触发上游内存 bug（见 OpenXSKernel AGENTS.md）。
- OVMF 用 `/usr/share/ovmf/OVMF.fd`（合并版），不要用 `OVMF_CODE_4M.fd` 直喂 `-bios`。
- 版本：OpenXSKernel v2.1.1、OpenXSBoot 2.1、leopard-getty 1.0、其余 1.0。
