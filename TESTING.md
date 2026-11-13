# LeopardOS 测试操作手册

## 一、测试目标

验证 LeopardOS 安装闭环：live ISO 启动 → 分区（ESP + ext4 root + /users）→ 格式化 → 挂载 → 从 /media 用 xbps 安装软件包 → 重启。

## 二、前置依赖

- qemu-system-x86_64（含 OVMF 固件，通常 /usr/share/ovmf/OVMF.fd）、qemu-img
- python3、ninja、clang（编译内核 / 引导器 / 组件）
- genisoimage、mtools(mmd/mcopy)、mkfs.vfat（ISO 构建）
- sgdisk(gdisk)、dd（img 途径磁盘镜像）

## 三、制造流程（模拟真机 ISO 安装）

### 1. 内核
    cd OpenXSKernel && ninja        # 产出 out/kernel.krl

### 2. 引导器
    cd OpenXSBoot && ninja          # 产出 out/BOOTX64.efi

### 3. 各组件（xbps 工具 + leopard-* 组件）
    每个组件目录：
      python3 gen_ninja.py && ninja build   # 产出 .elf
      ninja pack                            # 产出 .xbps（/media 安装源）

### 4. 制作 iso live
    cd LeopardOS
    INSTALLER_ARGS='sata0 --yes' sh build_liveroot.sh   # 无头自动安装；交互安装省略 INSTALLER_ARGS
    sh make_iso.sh                                      # 产出 leopard-installer.iso

### 5. 创建虚拟机（空目标盘）
    sh create_vm.sh                # 产出 target.vmdk（默认 5G，对齐官方推荐容量）

### 6. 启动
    sh run_install.sh              # 默认图形窗口
    HEADLESS=1 sh run_install.sh   # 无头（纯串口）；落日志可再加 QEMU_SERIAL=file:/path

### 7. 直接启动盘内系统（安装完成后）
    sh run_system.sh               # 引导 target.vmdk，无 ISO/CD
    HEADLESS=1 sh run_system.sh    # 无头

## 四、无头自动安装的串口日志要点

    Partitioning /dev/sata0 → Formatting ESP (FAT32) + ext4 root + /users →
    Mounted /dev/sata0p0 at /mnt → Installing base system from /media →
    Installation complete. Rebooting...

安装器是 respawn 的，失败会循环 分区→格式化→挂载→安装 而不退出。

## 五、img 途径（不经安装器，直接造预装镜像）

见 `img-tools/` 目录：

    cd img-tools
    sh make_image.sh               # 产出 XJ380.img + XJ380.vmdk（预装系统 FAT 镜像）
    sh run.sh                      # 引导预装镜像（默认图形窗口）
    HEADLESS=1 sh run.sh           # 无头（纯串口）

## 六、一键无头测试（推荐）

零输入，只看串口日志断言，不敲任何键：

    # 全链路：安装 + 启动（默认先打包全部组件，避免用到旧包）
    sh test_all.sh
    # 组件已打包：跳过打包
    BUILD=0 sh test_all.sh
    # 只跑安装 / 只跑启动
    sh test_install.sh
    sh test_boot.sh

- `test_install.sh`：空盘 → live ISO → 零输入自动安装（`finish=shutdown`）→ 断言各步骤日志。
  日志出现「全部步骤完成 / 关机 / 重启」后立即结束 QEMU，不再空等 TIMEOUT。
- `test_boot.sh`：引导已装盘，断言 `LeopardRC: init started` → `LeopardGetty: console login` →
  `Leopard OOBE: first boot setup`；出现登录/OOBE 后主动结束 QEMU。
- `test_all.sh`：`test_install.sh` + `test_boot.sh`，共用同一个 `WORK`，失败时打印日志尾部。
- 工作目录默认 `.testwork`（gitignored）；`KEEP=1` 保留日志、`WORK=` 换路径、`TIMEOUT=` 改超时。
- QEMU 默认有 `/dev/kvm` 就用 KVM + `-cpu host`，否则回退 TCG；可用 `QEMU_ACCEL=tcg`
  强制软件模拟。`QEMU_MEM`/`QEMU_SMP`/`QEMU_DISK_BUS=nvme`/`QEMU_NET=1`/`QEMU_AUDIO=1`/`QEMU_USB=1`
  见 `lib/qemu.sh` 顶部说明。

## 七、已知问题（详见 Bugzilla 邮件）

1. Bug #1（critical）：zstd 解压产出错数据（疑似 brk/mmap 懒分配损坏堆）。xbps 安装步骤会报 Zstd decompression failed（Data corruption / checksum mismatch），是当前安装闭环的阻塞项。
2. Bug #2（major）：AHCI IOBLKSYNC 空操作 + sata_submit_fast 异步写，写后立即读回脏数据（mount ENOENT，多数被格式化步骤的时间差掩盖）。
3. 交互模式依赖图形键盘输入；串口 stdio 只回显日志、不喂键盘。
