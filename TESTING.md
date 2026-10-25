# LeopardOS 安装场景测试操作手册

## 一、测试目标

验证 LeopardOS 安装闭环：live ISO 启动 → 分区 → 格式化 FAT32 → 挂载 → 从 /media 用 xbps 安装软件包 → 重启。

## 二、前置依赖

- qemu-system-x86_64（含 OVMF 固件，通常 /usr/share/ovmf/OVMF.fd）
- python3、ninja、clang（编译内核 / 引导器 / 组件）
- genisoimage、mtools(mmd/mcopy)、mkfs.vfat（ISO 构建）
- sgdisk(gdisk)、dd（磁盘镜像）

## 三、构建流程

### 1. 内核
    cd OpenXSKernel && ninja        # 产出 out/kernel.krl

### 2. 引导器
    cd OpenXSBoot && ninja          # 产出 out/BOOTX64.efi

### 3. 各组件（xbps 工具 + leopard-* 组件）
    每个组件目录：
      python3 gen_ninja.py && ninja build   # 产出 .elf
      ninja pack                            # 产出 .xbps（/media 安装源）

### 4. 组装 live root
    cd LeopardOS && sh build_liveroot.sh   # 产出 liveroot/（含 initrc + /media 包）

### 5. 打包 ISO
    cd LeopardOS && sh make_iso.sh         # 产出 leopard-installer.iso

### 6. 准备空目标盘
    qemu-img create -f vmdk -o subformat=monolithicSparse target.vmdk 1G

## 四、启动测试

### QEMU 启动（带图形窗口，交互需要键盘输入）
    qemu-system-x86_64 -M q35 -bios /usr/share/ovmf/OVMF.fd -m 2048 -cdrom leopard-installer.iso -drive if=none,id=hd,file=target.vmdk,format=vmdk -device ahci,id=ahci -device ide-hd,bus=ahci.0,drive=hd -serial stdio

注意：交互安装依赖图形窗口的键盘输入（PS/2），不能用 -display none 无头串口（敲不进去，已实测确认）。

### 交互步骤
1. 启动后安装器列出可用磁盘（Available disks）。
2. 输入目标盘名（如 sata0）并回车。
3. 确认提示输入 y 回车（会清空该盘数据）。
4. 安装器依次执行：分区(lpdisk) → 格式化(mkfs-fat32) → 挂载(/mnt) → xbps 安装 → 重启。

## 五、预期结果

| 步骤 | 预期 |
|------|------|
| 分区 | GPT + 1 个 ef00 分区，/dev/sata0p0 注册 |
| 格式化 | FAT32（mkfs-fat32 输出 1072676352 bytes 等）|
| 挂载 | Mounted /dev/sata0p0 at /mnt |
| xbps 安装 | 从 /media 安装 14 个包 |
| 重启 | Installation complete. Rebooting... |

## 六、已知问题（详见 Bugzilla 邮件）

1. Bug #1（critical）：zstd 解压产出错数据（疑似 brk/mmap 懒分配损坏堆）。xbps 安装步骤会报 Zstd decompression failed（Data corruption / checksum mismatch），是当前安装闭环的阻塞项。
2. Bug #2（major）：AHCI IOBLKSYNC 空操作 + sata_submit_fast 异步写，写后立即读回脏数据（mount ENOENT，多数被格式化步骤的时间差掩盖）。
3. 交互模式依赖图形键盘输入；串口 stdio 只回显日志、不喂键盘。

## 七、快速命令清单（已在当前工作区就绪时）

    cd LeopardOS
    sh build_liveroot.sh
    sh make_iso.sh
    qemu-img create -f vmdk -o subformat=monolithicSparse target.vmdk 1G
    # 然后用「四、启动测试」的 QEMU 命令启动
