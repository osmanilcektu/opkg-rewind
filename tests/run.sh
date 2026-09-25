#!/bin/sh
set -eu

BASE="${TMPDIR:-/tmp}/opkg-rewind-test.$$"
ROOT="$BASE/opt"
REWIND="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/src/rewind"
trap 'rm -rf "$BASE"' EXIT HUP INT TERM

mkdir -p "$ROOT/bin" "$ROOT/lib/opkg/info" "$ROOT/var/lib/opkg-rewind/transactions" "$ROOT/tmp" "$ROOT/etc"

write_status() {
    ver="$1"
    cat > "$ROOT/lib/opkg/status" <<EOS
Package: demo
Version: $ver
Status: install user installed
Architecture: all
Installed-Size: 1

EOS
}

write_demo_v1() {
    printf 'old\n' > "$ROOT/bin/demo"
    chmod 755 "$ROOT/bin/demo"
    printf '%s\n' "$ROOT/bin/demo" > "$ROOT/lib/opkg/info/demo.list"
    printf 'Package: demo\nVersion: 1.0\n' > "$ROOT/lib/opkg/info/demo.control"
    write_status 1.0
}

cat > "$ROOT/bin/opkg" <<'EOS'
#!/bin/sh
set -u
ROOT="${REWIND_ROOT:?}"
STATUS="$ROOT/lib/opkg/status"
INFO="$ROOT/lib/opkg/info"

status_pkg() {
    pkg="$1"
    awk -v p="$pkg" '
        BEGIN { RS=""; FS="\n" }
        {
            found=0
            for (i=1;i<=NF;i++) if ($i == "Package: " p) found=1
            if (found) { print $0 "\n"; exit }
        }
    ' "$STATUS"
}

if [ "${1:-}" = "--noaction" ]; then
    shift
    action="$1"; shift
    case "$action:$1" in
        upgrade:demo)
            echo "Upgrading demo on root from 1.0 to 2.0..."
            exit 0
            ;;
        upgrade:opkg)
            echo "Upgrading opkg on root from 1.0 to 2.0..."
            exit 0
            ;;
        install:newpkg)
            echo "Installing newpkg (1.0) to root..."
            exit 0
            ;;
        remove:demo)
            echo "Removing package demo from root..."
            exit 0
            ;;
        remove:newpkg)
            echo "Removing package newpkg from root..."
            exit 0
            ;;
    esac
    exit 0
fi

case "${1:-}" in
    status)
        status_pkg "$2"
        ;;
    list-installed)
        awk '
            /^Package: / { p=$2 }
            /^Version: / { v=$2 }
            /^Status: / && $0 ~ / installed$/ { print p " - " v }
        ' "$STATUS"
        ;;
    update)
        echo "Updated mock lists"
        ;;
    upgrade)
        pkg="$2"
        [ "$pkg" = demo ] || exit 1
        printf 'new\n' > "$ROOT/bin/demo"
        printf 'new-extra\n' > "$ROOT/bin/demo-extra"
        printf '%s\n%s\n' "$ROOT/bin/demo" "$ROOT/bin/demo-extra" > "$INFO/demo.list"
        printf 'Package: demo\nVersion: 2.0\n' > "$INFO/demo.control"
        cat > "$STATUS" <<EOF2
Package: demo
Version: 2.0
Status: install user installed
Architecture: all
Installed-Size: 2

EOF2
        if [ "${FAKE_OPKG_FAIL:-0}" = 1 ]; then
            echo "simulated upgrade failure" >&2
            exit 7
        fi
        echo "Configuring demo."
        ;;
    install)
        pkg="$2"
        [ "$pkg" = newpkg ] || exit 1
        printf 'newpkg\n' > "$ROOT/bin/newpkg"
        printf '%s\n' "$ROOT/bin/newpkg" > "$INFO/newpkg.list"
        printf 'Package: newpkg\nVersion: 1.0\n' > "$INFO/newpkg.control"
        cat >> "$STATUS" <<EOF2
Package: newpkg
Version: 1.0
Status: install user installed
Architecture: all
Installed-Size: 1

EOF2
        ;;
    remove)
        pkg="$2"
        case "$pkg" in
            demo)
                rm -f "$ROOT/bin/demo" "$INFO/demo.list" "$INFO/demo.control"
                : > "$STATUS"
                ;;
            newpkg)
                if [ "${FAKE_OPKG_REMOVE_LEAVES_FILE:-0}" != 1 ]; then
                    rm -f "$ROOT/bin/newpkg"
                fi
                rm -f "$INFO/newpkg.list" "$INFO/newpkg.control"
                awk -v p="newpkg" '
                    BEGIN { RS=""; FS="\n"; ORS="\n\n" }
                    {
                        keep=1
                        for (i=1;i<=NF;i++) if ($i == "Package: " p) keep=0
                        if (keep) print $0
                    }
                ' "$STATUS" > "$STATUS.tmp"
                mv "$STATUS.tmp" "$STATUS"
                ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
EOS
chmod +x "$ROOT/bin/opkg"

run_rewind() {
    REWIND_ROOT="$ROOT" REWIND_OPKG="$ROOT/bin/opkg" REWIND_CONFIG="$BASE/no-config" "$REWIND" "$@"
}

assert_eq() {
    expected="$1" actual="$2" msg="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $msg: expected '$expected', got '$actual'" >&2
        exit 1
    fi
}

assert_file() { [ -e "$1" ] || { echo "FAIL: missing file $1" >&2; exit 1; }; }
assert_no_file() { [ ! -e "$1" ] || { echo "FAIL: unexpected file $1" >&2; exit 1; }; }

# 1) Failed upgrade must restore both original file and metadata and remove new file.
write_demo_v1
if FAKE_OPKG_FAIL=1 run_rewind upgrade demo >/dev/null 2>&1; then
    echo "FAIL: failed opkg upgrade unexpectedly returned success" >&2
    exit 1
fi
assert_eq "old" "$(cat "$ROOT/bin/demo")" "failed upgrade rollback content"
assert_no_file "$ROOT/bin/demo-extra"
assert_eq "1.0" "$(run_rewind lock "$BASE/test.lock" >/dev/null; awk -F'|' '$1=="demo"{print $2}' "$BASE/test.lock")" "failed upgrade rollback package DB"

# 2) Successful upgrade commits; latest rollback restores v1 and removes introduced file.
write_demo_v1
FAKE_OPKG_FAIL=0 run_rewind upgrade demo >/dev/null
assert_eq "new" "$(cat "$ROOT/bin/demo")" "successful upgrade content"
assert_file "$ROOT/bin/demo-extra"
run_rewind rollback >/dev/null
assert_eq "old" "$(cat "$ROOT/bin/demo")" "manual rollback content"
assert_no_file "$ROOT/bin/demo-extra"

# 3) New package install followed by rollback removes it cleanly.
# Simulate a package remove script that leaves the payload behind; Rewind's
# preserved post-install manifest must still delete the orphan.
write_demo_v1
install_out="$(run_rewind install newpkg)"
printf '%s\n' "$install_out" | grep -F '[+] Transaction 000003 committed' >/dev/null || {
    echo "FAIL: committed transaction id was corrupted by internal loop state" >&2
    exit 1
}
assert_file "$ROOT/bin/newpkg"
FAKE_OPKG_REMOVE_LEAVES_FILE=1 run_rewind rollback >/dev/null
assert_no_file "$ROOT/bin/newpkg"
assert_no_file "$ROOT/lib/opkg/info/newpkg.list"

# 4) Deep verify should pass on known-good state.
run_rewind doctor --deep >/dev/null

# 5) Core package mutation must be blocked before real opkg execution.
if run_rewind upgrade opkg >/dev/null 2>&1; then
    echo "FAIL: core package upgrade was not blocked" >&2
    exit 1
fi

# 6) Lock audit must detect a version drift.
run_rewind lock "$BASE/good.lock" >/dev/null
sed 's/demo|1.0/demo|9.9/' "$BASE/good.lock" > "$BASE/bad.lock"
if run_rewind lock-check "$BASE/bad.lock" >/dev/null 2>&1; then
    echo "FAIL: lock-check did not detect drift" >&2
    exit 1
fi

# 7) Verify must detect a missing owned file.
rm -f "$ROOT/bin/demo"
if run_rewind verify demo >/dev/null 2>&1; then
    echo "FAIL: verify did not detect a missing package-owned file" >&2
    exit 1
fi
printf 'old\n' > "$ROOT/bin/demo"
chmod 755 "$ROOT/bin/demo"

# 8) Rolling back an older retained transaction after a newer one must become
# the latest drift baseline by event time, not by transaction number.
write_demo_v1
run_rewind install newpkg >/dev/null
run_rewind remove newpkg >/dev/null
run_rewind rollback >/dev/null
run_rewind rollback 000004 >/dev/null
if ! run_rewind status | grep -F 'Package DB drift: no' >/dev/null; then
    echo "FAIL: chronological baseline selection failed after older transaction rollback" >&2
    exit 1
fi

# 9) Direct/out-of-band package DB changes must be reported as drift.
cat >> "$ROOT/lib/opkg/status" <<'EOS'
Package: outside
Version: 1.0
Status: install user installed
Architecture: all
Installed-Size: 1

EOS
if ! run_rewind status | grep -F 'Package DB drift: YES' >/dev/null; then
    echo "FAIL: status did not report out-of-band package DB drift" >&2
    exit 1
fi
write_status 1.0

# Final status must return to the latest Rewind baseline.
if ! run_rewind status | grep -F 'Package DB drift: no' >/dev/null; then
    echo "FAIL: status did not clear package DB drift after baseline restore" >&2
    exit 1
fi

echo "PASS: all OPKG Rewind tests"
