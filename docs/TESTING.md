# LeopardOS 测试操作手册

## 1. 前置依赖

- `qemu-system-x86_64`、`qemu-img`、OVMF（通常 `/usr/share/ovmf/OVMF.fd`）
- `python3`、`ninja`、`clang`
- `xorriso`、`dosfstools`、`mtools`
- `sgdisk`、`mkfs.ext4`
- `socat`（`tests/test_cli.sh` 用 QEMU monitor 注入键盘）

## 2. 构建组件包

```sh
sh build/build_all.sh
```

只打包，不组装。产物在各组件 `out/`。

## 3. 生成安装介质

```sh
sh live/build_liveroot.sh
sh live/make_iso.sh
# → leopard-installer.iso
```

无头自动安装的 live 配置：

```sh
INSTALLER_ARGS='sata0 --yes' sh live/build_liveroot.sh
sh live/make_iso.sh
```

`INSTALLER_ARGS` 会写入 `auto=1 / disk=... / finish=...`。

## 4. 运行安装器

```sh
sh vm/create_vm.sh          # → target.vmdk (5G)
sh vm/run_install.sh        # 图形窗口
HEADLESS=1 sh vm/run_install.sh
```

安装器由 live `initrc` 里的 conhost 在 PTY 上启动；安装进度同时镜像到串口
（安装器自身的 serial mirror），无头测试直接断言 serial 日志。软件选择由
`leopard-installer/data/package-profiles.conf` 的 `core.packages` + `groups` +
`minimal/standard/full/custom` 决定，默认 `standard`（控制台工具 + IME）。

## 5. 启动已安装系统

```sh
sh vm/run_system.sh
HEADLESS=1 sh vm/run_system.sh
```

已装系统的 `initrc` 先跑 `leopard-mountd`，再 `respawn conhost`；conhost 拥有
console/VT，在 PTY 上启动 getty，getty 登录后 exec 用户 shell。conhost 会把
PTY 输出镜像到串口，因此 `HEADLESS=1` 也能看到 rc/getty/OOBE/shell 的输出。
串口只输出；键盘仍是 PS/2。

## 6. 预装镜像

```sh
sh image/make_image.sh      # → image/XJ380.img / image/XJ380.vmdk
sh image/run_image.sh
HEADLESS=1 sh image/run_image.sh
```

## 7. 一键无头测试

```sh
# 全链路：打包 + 安装 + 启动
sh tests/test_all.sh

# 已打包，跳过重打包
BUILD=0 sh tests/test_all.sh

# 只跑安装 / 只跑启动
sh tests/test_install.sh
sh tests/test_boot.sh

# 登录 + CLI（使用同一个 WORK）
WORK=.testwork bash tests/test_cli.sh
```

- `test_install.sh`：空盘 → live ISO → 零输入自动安装（`finish=shutdown`）→ 断言日志。
  断言来自安装器的 serial mirror：每步标题（`== ... ==`）、`installer: all steps complete.`、
  无 `installer: step failed`。
- `test_boot.sh`：引导已装盘，断言 rc → getty → OOBE；串口内容来自 conhost 的 PTY mirror。
- `tests/test_all.sh`：安装 + 启动，共用 `WORK`。
- `test_cli.sh`：OOBE 建号 → getty 登录 → `lpsh` → CLI 命令（含 `whoami`、
  `pwdx` + Backspace 退格回归、`doas poweroff`）。
  不再检查 console_lock（该锁已删除；conhost 是 console 的唯一拥有者）。
  2.2.1 起裸 `poweroff` 仅允许 Root/System，Admin 通过 setuid `doas` 提权。
- 工作目录默认 `.testwork`（gitignored）；`KEEP=1` 保留，`WORK=` 换路径，`TIMEOUT=` 改超时。

## 8. QEMU 参数

见 `lib/qemu.sh` 顶部：

```
HEADLESS=1
QEMU_SERIAL=file:/path
QEMU_ACCEL=auto|kvm|tcg
QEMU_MEM=2048 QEMU_SMP=4
QEMU_DISK_BUS=sata|nvme
QEMU_NET=1 QEMU_AUDIO=1 QEMU_USB=1
QEMU_GDB=1 QEMU_PAUSE=1 QEMU_NO_REBOOT=1
```

## 9. 已知限制

- `/media` 仍在 live-root.img 内，启动时随 PE 一起解到 RAM。
- 预装镜像仍走 `build/packages.conf`，安装器 ISO 走 `../leopard-packages/media.list`，两份清单尚未统一。
- 串口是输出-only（conhost PTY mirror + 安装器 serial mirror）；交互测试的键盘输入
  仍要靠 QEMU monitor `sendkey`（PS/2）。
- 安装器默认软件方案 `standard` 已包含 IME；需要网络/USB 模块时选 `full`
  或在 `leopard-install.conf` 显式写 `modules=`。
