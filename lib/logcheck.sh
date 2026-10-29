# lib/logcheck.sh — 测试脚本共用日志断言
# 用法：. "$ROOT/lib/logcheck.sh"
#   assert_log    <log> <固定字符串> <说明>     # 日志必须包含
#   assert_no_log <log> <固定字符串> <说明>     # 日志不得包含
#   summary <标题>                              # 汇总；FAIL>0 返回非 0

PASS=0
FAIL=0
FAILED_LIST=""

_lc_pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
_lc_fail() { FAIL=$((FAIL + 1)); FAILED_LIST="$FAILED_LIST
    - $1"; echo "  [FAIL] $1"; }

assert_log() {
    log="$1"; pat="$2"; desc="$3"
    if [ -f "$log" ] && grep -qF -- "$pat" "$log"; then
        _lc_pass "$desc"
    else
        _lc_fail "$desc（缺: $pat）"
    fi
}

assert_no_log() {
    log="$1"; pat="$2"; desc="$3"
    if [ -f "$log" ] && grep -qF -- "$pat" "$log"; then
        _lc_fail "$desc（意外出现: $pat）"
    else
        _lc_pass "$desc"
    fi
}

summary() {
    echo
    echo "===== $1 ====="
    echo "PASS=$PASS FAIL=$FAIL"
    if [ "$FAIL" -ne 0 ]; then
        printf '失败项:%s\n' "$FAILED_LIST"
        return 1
    fi
    echo "全部通过"
    return 0
}
