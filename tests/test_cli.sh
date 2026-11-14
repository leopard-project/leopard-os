#!/bin/bash
set -u

# 测试已装系统 CLI 软件可用性：OOBE 建号 -> 登录 -> 跑命令 -> 断言串口
# 内核键盘输入走 PS/2、串口只输出不回读输入，故用 QEMU monitor sendkey 注入键盘。

ROOT=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$ROOT/.." && pwd)
WORK="${WORK:-$REPO/.testwork}"
DISK="${DISK:-$WORK/target.vmdk}"
LOG="$WORK/cli.log"
MON="${MON:-/tmp/qemu-cli-mon.sock}"
USER="${CLI_USER:-admin}"
PASS="${CLI_PASS:-admin}"

. "$REPO/lib/logcheck.sh"

[ -f "$DISK" ] || { echo "无系统盘: $DISK（先跑 test_install.sh，或设 DISK）" >&2; exit 1; }

rm -f "$MON"
: > "$LOG"

qemu-system-x86_64 -M q35 -bios /usr/share/ovmf/OVMF.fd -m 2048 -smp 4 -drive if=none,id=hd,file="$DISK",format=vmdk -device ahci,id=ahci -device ide-hd,bus=ahci.0,drive=hd,bootindex=0 -display none -serial "file:$LOG" -monitor "unix:$MON,server,nowait" -no-reboot &
QEMU_PID=$!

# 等 pattern 在日志中出现至少 cnt 次（OOBE 和登录会各打印一次 Username:/Password:，
# 用出现次数区分，避免字节偏移追踪背靠背写入时漏掉提示）。
wait_for() {
  local pat="$1" cnt="$2" tmo="$3" desc="$4" i=0 n
  while [ "$i" -lt "$tmo" ]; do
    n=$(grep -oF -- "$pat" "$LOG" 2>/dev/null | wc -l)
    if [ "$n" -ge "$cnt" ]; then
      echo "  [ok] $desc"
      return 0
    fi
    sleep 1; i=$((i+1))
  done
  echo "  [FAIL] $desc (超时等不到: $pat x$cnt)"
  return 1
}

mon() { echo "$1" | socat - "UNIX-CONNECT:$MON" 2>/dev/null; }
sendkey() { mon "sendkey $1"; sleep 0.05; }

keyname() {
  case "$1" in
    [a-z]) echo "$1" ;;
    [0-9]) echo "$1" ;;
    " ") echo spc ;;
    "-") echo minus ;;
    ".") echo dot ;;
    "/") echo slash ;;
    *) echo "" ;;
  esac
}

sendstr() {
  local s="$1" c k i
  for ((i=0; i<${#s}; i++)); do
    c="${s:$i:1}"
    k=$(keyname "$c")
    [ -n "$k" ] && sendkey "$k"
    sleep 0.06
  done
  sendkey ret
  sleep 0.5
}

echo ">>> 启动并等待 OOBE"
wait_for "Leopard OOBE: first boot setup" 1 60 "进入 OOBE" || { kill $QEMU_PID 2>/dev/null; exit 1; }
wait_for "Username: " 1 10 "OOBE 用户名提示" || { kill $QEMU_PID 2>/dev/null; exit 1; }
sendstr "$USER"
wait_for "Password: " 1 10 "OOBE 密码提示" || { kill $QEMU_PID 2>/dev/null; exit 1; }
sendstr "$PASS"
wait_for "account created" 1 20 "账号创建成功" || { kill $QEMU_PID 2>/dev/null; exit 1; }

echo ">>> 登录"
wait_for "Username: " 2 30 "登录用户名提示" || { kill $QEMU_PID 2>/dev/null; exit 1; }
sendstr "$USER"
wait_for "Password: " 2 10 "登录密码提示" || { kill $QEMU_PID 2>/dev/null; exit 1; }
sendstr "$PASS"
wait_for "lpsh" 1 30 "进入 lpsh shell" || { kill $QEMU_PID 2>/dev/null; exit 1; }

echo ">>> 跑 CLI 命令"
run_cmd() { echo ">>> $*"; sendstr "$*"; sleep 1.5; }
# 嵌套 leopard-getty 必须被拒绝，且不能抢走当前 getty 的输入焦点
run_cmd "leopard-getty"
wait_for "already inside a terminal session" 1 10 "嵌套 leopard-getty 被拒绝" || { kill $QEMU_PID 2>/dev/null; exit 1; }
run_cmd "pwd"
run_cmd "initctl list"
run_cmd "lpdisk list"
run_cmd "mkfs-fat32"
run_cmd "xbps-query -l"
run_cmd "poweroff"

echo ">>> 等 VM 关机"
i=0
while [ "$i" -lt 30 ] && kill -0 "$QEMU_PID" 2>/dev/null; do sleep 1; i=$((i+1)); done

echo ">>> 断言"
assert_log "$LOG" "lpsh" "shell 提示符"
assert_log "$LOG" "already inside a terminal session" "嵌套 leopard-getty 被拒绝"
assert_log "$LOG" "/users/$USER" "pwd 输出 home"
assert_log "$LOG" "leopard-getty" "initctl list 列出服务"
assert_log "$LOG" "Block devices:" "lpdisk list 列块设备"
assert_log "$LOG" "usage: mkfs-fat32" "mkfs-fat32 打印用法"
assert_no_log "$LOG" "command not found" "所有命令都被找到"
assert_log "$LOG" "The system will poweroff now" "poweroff 生效"

summary "CLI 软件可用性测试"
