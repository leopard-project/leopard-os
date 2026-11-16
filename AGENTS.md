# PROJECT KNOWLEDGE BASE — LeopardOS

镜像组装仓库（非 gen_ninja 组件）：把内核 + 引导 + 各用户态组件 + 配置打包成可启动镜像。

## 目录 / 脚本

```
build/      组件打包（build_all / packages.conf）
image/      预装镜像（assemble_image / make_image / run_image）
live/       最小 PE + ISO（build_liveroot / make_iso / pe.list / boot.conf / makepak.py）
tests/      无头测试（test_all / test_install / test_install_tui / test_boot / test_cli）
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
- `build/build_all.sh` — 按 `build/packages.conf` 打包全部组件（只打包，不组装）。
- `build/packages.conf` — 组件清单（目录/构建脚本/包名）；包含
  `leopard-doas` / `leopard-ime`，保证 `assemble_image` 也能装输入法与权限工具。
- `lib/qemu.sh` — QEMU 共用样板（`qemu_boot <disk> [iso]` + OVMF 探测）。
- `lib/logcheck.sh` — 测试日志断言库（`assert_log` / `assert_no_log` / `summary`）。
- `tests/test_install.sh` — 空盘→ISO→零输入自动安装→断言串口日志。
- `tests/test_install_tui.sh` — 交互 TUI 安装：QEMU monitor `sendkey` 走完
  欢迎/磁盘/方案/确认/收尾，串口断言 `installer: ui ...` 标记。
- `tests/test_boot.sh` — 无头启动测试（rc→getty→OOBE）。
- `tests/test_all.sh` — 安装 + 启动全链路（共用 WORK）。
- `tests/test_cli.sh` — OOBE 建号→登录→跑 CLI→poweroff。
- `vm/run_system.sh` / `vm/run_install.sh` / `image/run_image.sh` — QEMU 跑系统/安装器/预装镜像。
- `vm/create_vm.sh` — 生成 VM 磁盘。
- `live/makepak.py` — XJPAK10 live-root 打包。

## 组件清单（packages.conf / media.list）

- 安装介质 `/media` 的包清单在 `../leopard-packages/media.list`；由
  `leopard-src sync` 生成受控仓库，`live/build_liveroot.sh` 只消费它。
- 预装镜像的组件清单仍是 `build/packages.conf`，格式 `<目录> <构建脚本> <包名>`。
  `image/make_image.sh` 读前两列打包，`image/assemble_image.sh` 读第 1、3 列收包并安装。
- PE-only 包（`leopard-installer`、`xbps-create`、`xbps-rindex`）不得进入
  `media.list`；目标用户态包不得进入 `live/pe.list`。
- 注意 `leopard-xbps` 目录出的包名是 `xbps`（与目录名不同）。

## 关键事实
- **console 架构**：`leopard-base` 的 `system/config/initrc` 先一次性跑
  `leopard-mountd`，再 `respawn /apps/leopard/leopard-conhost.elf`。conhost 拥有
  console/VT，在 PTY 上启动 getty；getty 登录后在同一会话 exec 用户 shell。
  live 环境的 initrc 让 conhost 在 PTY 上运行安装器。`console_lock` 已删除，
  conhost 是 console 的唯一拥有者。
- **无头串口输出**：conhost 把 PTY 输出镜像到串口（PTY serial mirror），
  安装器另外把步骤日志/顶层消息直接镜像到串口；因此 `tests/test_install.sh`
  和 `tests/test_boot.sh` 只 grep QEMU serial 日志即可。串口仍是输出-only，
  键盘输入走 PS/2，`test_cli.sh` / `test_install_tui.sh` 用 QEMU monitor 注入。
- **PTY fd 计数**：`vfs_close()` 对 PTY 的每次 close 都要调用 close 回调；
  `slave_fds` / `master_fds` 是句柄计数，不是节点引用计数。不要改成只在
  `node->refcount == 0` 时调用：slave 节点有 `pair->slave_node` 的创建引用，
  refcount 永远不归零，conhost 会等不到 master EOF，OOBE 退出后 getty 不重启。
- **conhost 会话收尾**：`leopard-conhost 1.0_6` 在 `waitpid()` 看到会话子进程
  退出（或 ECHILD）后立即关闭用于 `TCGETS` 的缓存 slave fd，否则这个额外
  slave 引用会拖住 PTY，master 读不到 EOF。
- **安装器 TUI**：`main.c` 独占 lpcurses 屏幕；步骤通过 `LI_UI_FD` /
  `LI_UI_OUT_FD` 发菜单/输入/确认请求。`auto=1` 和非 tty 不初始化 curses；
  `LEOPARD_INSTALL_TUI=0` 强制行模式。
- **安装器软件方案**：`leopard-installer/data/package-profiles.conf` 是
  `core.packages` + `group.<id>` + `package.<id>` 声明式模型；`standard`（默认）
  含控制台工具和 IME，`full` 再加网络/USB 模块。分区布局只看
  `install-profiles.conf`。
- **关机/重启权限**：OpenXSKernel 2.2.1 起 `XAPI_POWER_ACTION` 只允许
  Root/System；Admin 登录后使用 `doas poweroff` / `doas reboot`，测试也走这条路径。
- 预装镜像（modern，默认 5 GiB）：GPT = ESP 64 MiB FAT32 + ext4 root + ext4 /users；
  root/users 用 `mkfs.ext4 -d` 直接铺 `.stage`，ESP 写 `BOOTX64.EFI`、`kernel.krl`、
  `boot.conf`、`EFI/XJ380/root.bin`。
- live ISO：live-root.img 解到 tmpfs，安装器再做现代布局。当前 `/media` 仍在
  live-root.img 内（会随 PE 一起进 RAM）；真正的“介质上的 /media”需要把 media
  镜像从 live-root.img 拆出去，并在引导器/内核侧提供访问方式，尚未实现。
- xbps 包/repodata 用 **gzip** 压缩（不是 zstd）——zstd 会触发上游内存 bug（见 OpenXSKernel AGENTS.md）。
- OVMF 用 `/usr/share/ovmf/OVMF.fd`（合并版），不要用 `OVMF_CODE_4M.fd` 直喂 `-bios`。
- 版本：OpenXSKernel v2.2.1_1（本次重建：移除 XAPI 文本 syscall；PTY fd
  实验已回退，不升版本）、
  OpenXSBoot 2.1.1_2、leopard-base 1.0.2_1、leopard-rc 1.0_4、
  leopard-getty 1.0_5、leopard-conhost 1.0_6、leopard-doas 1.0_2、
  leopard-ime 1.1_1、leopard-shell 1.0_5、leopard-utils 1.0_2、
  leopard-installer 1.6.0_1、lpcurses 1.0_2、其余 1.0_1。
