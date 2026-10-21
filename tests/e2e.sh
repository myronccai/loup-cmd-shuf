#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), standard error where it matters, and exit status with the
# expected ones. Every random case uses --seed or --random-source, so the
# expected output is exact; the same seeds give the same output under
# `loup run` and Stage0.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

report() {
    local name=$1 status=$2 want_status=$3 want_file=$4 got_file=$5
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$got_file"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$got_file") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check_file NAME STATUS EXPECTED_FILE [ARGS...]: standard input from the
# file named by $IN (default /dev/null); compares standard output.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    report "$name" $? "$want_status" "$want_file" "$TMP/out"
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]. Bash strings cannot hold NUL
# bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]: compares standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    report "$name" $? "$want_status" "$TMP/want" "$TMP/err"
}

# check_sorted NAME EXPECTED [ARGS...]: the output, sorted, must equal
# EXPECTED: for unseeded runs, whose order changes every time.
check_sorted() {
    local name=$1
    printf '%s' "$2" > "$TMP/want"
    shift 2
    "$BIN" "$@" < "${IN:-/dev/null}" 2> "$TMP/err" | LC_ALL=C sort > "$TMP/sorted"
    report "$name" "${PIPESTATUS[0]}" 0 "$TMP/want" "$TMP/sorted"
}

# --- inputs ----------------------------------------------------------------

check "-e"                     0 $'e\nc\na\nb\nd\n'          --seed 1 -e a b c d e
check "-n"                     0 $'e\nc\n'                   --seed 1 -n 2 -e a b c d e
check "-n larger than input"   0 $'e\nc\na\nb\nd\n'          --seed 1 -n 99 -e a b c d e
check "smallest -n wins"       0 $'e\n'                      --seed 1 -n 3 -n 1 -n 2 -e a b c d e
check "-i"                     0 $'2\n7\n1\n10\n8\n9\n5\n6\n3\n4\n' --seed 2 -i 1-10
check "-i with -n"             0 $'2\n7\n1\n'                --seed 2 -i 1-10 -n 3
check "-i large range"         0 $'892874\n918409\n599566\n471399\n' --seed 2 -i 1-1000000 -n 4
check "-i one number"          0 $'0\n'                      --seed 5 -i 0-0
check "-i empty range"         0 ''                          --seed 5 -i 5-4
printf 'one\ntwo\nthree' > "$TMP/three.txt"
check "file, no final newline" 0 $'three\ntwo\none\n'        --seed 7 "$TMP/three.txt"
IN=$TMP/three.txt check "standard input" 0 $'three\ntwo\none\n' --seed 7
IN=$TMP/three.txt check "- is standard input" 0 $'three\ntwo\none\n' --seed 7 -
printf '' > "$TMP/empty.txt"
check "empty input"            0 ''                          --seed 7 "$TMP/empty.txt"
printf 'a\n\nb\n' > "$TMP/blank.txt"
check_sorted "empty lines kept" $'\na\nb\n'                  "$TMP/blank.txt"
check "-- ends options"        0 $'x\n-n\n'                  --seed 6 -e -- -n x
check "long option prefixes"   0 $'e\nc\n'                   --seed=1 --head=2 --ec a b c d e

printf 'a\0b\0c\0' > "$TMP/nul.in"
printf 'b\0a\0c\0' > "$TMP/nul.want"
check_file "-z"                0 "$TMP/nul.want"             --seed 4 -z -e a b c
IN=$TMP/nul.in check_file "-z input" 0 "$TMP/nul.want"       --seed 4 -z

# --- randomness --------------------------------------------------------------------

check "--repeat"               0 $'y\ny\nx\ny\nx\nz\nx\nx\n'  --seed 3 -r -n 8 -e x y z
check "--repeat range"         0 $'379221\n927162\n539291\n815979\n285779\n' --seed 3 -r -n 5 -i 1-1000000
check "--repeat one line"      0 $'solo\nsolo\nsolo\n'       --seed 3 -r -n 3 -e solo
check "--random-source"        0 $'1\n3\n4\n5\n2\n6\n'      --random-source=/dev/zero -i 1-6
printf 'foobar' > "$TMP/bytes"
"$BIN" --random-source "$TMP/bytes" -i 1-50 > "$TMP/first" 2> "$TMP/err"
"$BIN" --random-source "$TMP/bytes" -i 1-50 > "$TMP/second" 2> "$TMP/err"
report "same source, same order" 0 0 "$TMP/first" "$TMP/second"
seq 1 50 > "$TMP/ordered"
check_sorted "clock seed: a permutation" "$(LC_ALL=C sort "$TMP/ordered")"$'\n' -i 1-50
# --repeat without -n never stops. A pipe into `head` would rely on SIGPIPE,
# which CI runners may ignore (and native writes ignore EPIPE), so stop it
# with `timeout` instead and look at what it wrote to a file.
timeout 1 "$BIN" -r -i 1-3 > "$TMP/endless" 2> "$TMP/err"
status=$?
lines=$(wc -l < "$TMP/endless")
others=$(grep -cvx '[123]' "$TMP/endless")
if [ "$status" -eq 124 ] && [ "$lines" -gt 1000 ] && [ "$others" -le 1 ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --repeat without -n (exit $status, $lines lines, $others others)"
fi
check "-n 0 reads nothing"     0 ''                          -n 0 "$TMP/missing"

# --- output files --------------------------------------------------------------------

check "-o"                     0 ''                          --seed 1 -o "$TMP/out.txt" -e a b c d e
printf 'e\nc\na\nb\nd\n' > "$TMP/want.txt"
report "-o file" 0 0 "$TMP/want.txt" "$TMP/out.txt"
cp "$TMP/three.txt" "$TMP/inplace.txt"
check "-o onto the input"      0 ''                          --seed 7 -o "$TMP/inplace.txt" "$TMP/inplace.txt"
printf 'three\ntwo\none\n' > "$TMP/want.txt"
report "-o in place" 0 0 "$TMP/want.txt" "$TMP/inplace.txt"
check "-n 0 -o"                0 ''                          -n 0 -e a -o "$TMP/zero.txt"
report "-n 0 makes an empty file" 0 0 "$TMP/empty.txt" "$TMP/zero.txt"

# --- errors ------------------------------------------------------------------------------

HINT="Try 'shuf --help' for more information."
check_err "missing file"       1 $'shuf: nope: No such file or directory\n'    nope
check_err "directory"          1 $'shuf: read error: Is a directory\n'          "$TMP"
check_err "extra operand"      1 "shuf: extra operand 'b'
$HINT
" a b
check_err "-e with -i"         1 "shuf: cannot combine -e and -i options
$HINT
" -e -i 1-3
check_err "operand with -i"    1 "shuf: extra operand 'x'
$HINT
" -i 1-3 x
check_err "bad range"          1 $'shuf: invalid input range: \'5-3\'\n'        -i 5-3
check_err "two ranges"         1 $'shuf: multiple -i options specified\n'       -i 1-2 -i 3-4
check_err "bad count"          1 $'shuf: invalid line count: \'x\'\n'           -n x
check_err "bad seed"           1 $'shuf: invalid seed: \'1.5\'\n'               --seed 1.5
check_err "two sources"        1 $'shuf: multiple random sources specified\n'   --seed 1 --random-source=/dev/zero
check_err "two outputs"        1 $'shuf: multiple output files specified\n'     -o a -o b
check_err "nothing to repeat"  1 $'shuf: no lines to repeat\n'                  -r
check_err "missing source"     1 $'shuf: none: No such file or directory\n'     --random-source=none -e a b
check_err "empty source"       1 $'shuf: \'/dev/null\': end of file\n'          --random-source=/dev/null -e a b
check "one line needs no bytes" 0 $'a\n'                     --random-source=/dev/null -e a
check_err "output directory"   1 "shuf: $TMP: Is a directory
" -o "$TMP" -e a
check_err "invalid option"     1 "shuf: invalid option -- 'x'
$HINT
" -x
check_err "ambiguous option"   1 "shuf: option '--r' is ambiguous; possibilities: '--random-source' '--repeat'
$HINT
" --r
check_err "missing value"      1 "shuf: option requires an argument -- 'n'
$HINT
" -n

check "version"                0 $'shuf (loup-cmd-shuf) 0.1.0\n' --version
"$BIN" --help > "$TMP/out" 2> "$TMP/err"
head -1 "$TMP/out" > "$TMP/got"
printf 'Usage: shuf [OPTION]... [FILE]\n' > "$TMP/want"
report "help" $? 0 "$TMP/want" "$TMP/got"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
