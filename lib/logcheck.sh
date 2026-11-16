# lib/logcheck.sh — shared log assertions for test scripts
# Usage: . "$ROOT/lib/logcheck.sh"
#   assert_log    <log> <literal> <desc>     # log must contain
#   assert_no_log <log> <literal> <desc>     # log must not contain
#   summary <title>                          # summary; returns non-zero if FAIL>0

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

# wait_for_log <log> <seconds> <pattern> [pattern...]
# Poll the log; return 0 when any pattern appears, 1 on timeout.
wait_for_log() {
    _wfl_log="$1"; _wfl_timeout="$2"; shift 2
    _wfl_n=0
    while [ "$_wfl_n" -lt "$_wfl_timeout" ]; do
        for _wfl_pat in "$@"; do
            if [ -f "$_wfl_log" ] && grep -qF -- "$_wfl_pat" "$_wfl_log"; then
                return 0
            fi
        done
        sleep 1
        _wfl_n=$((_wfl_n + 1))
    done
    return 1
}

# wait_for_log_pid <log> <seconds> <pid> <pattern> [pattern...]
# Like wait_for_log, but returns 1 early when the pid has exited.
wait_for_log_pid() {
    _wlp_log="$1"; _wlp_timeout="$2"; _wlp_pid="$3"; shift 3
    _wlp_n=0
    while [ "$_wlp_n" -lt "$_wlp_timeout" ]; do
        kill -0 "$_wlp_pid" 2>/dev/null || return 1
        for _wlp_pat in "$@"; do
            if [ -f "$_wlp_log" ] && grep -qF -- "$_wlp_pat" "$_wlp_log"; then
                return 0
            fi
        done
        sleep 1
        _wlp_n=$((_wlp_n + 1))
    done
    return 1
}
