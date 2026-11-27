#!/bin/sh
set -eu

cd "$(dirname "$0")"
query="SELECT category, SUM(amount)::BIGINT AS total FROM read_csv('fixture.csv') GROUP BY category ORDER BY category;"
expected='category,total
alpha,42
beta,5'

"$@" --version
start=$(date +%s)
actual=$("$@" -c "$query")
end=$(date +%s)
printf '%s\n' "$actual"
test "$actual" = "$expected"
printf 'CSV wall time: %s s (whole-second shell clock)\n' "$((end - start))"

test "$("$@" -c "SELECT category, SUM(amount)::BIGINT AS total FROM read_json('fixture.json') GROUP BY category ORDER BY category;")" = "$expected"
# Array-valued results from JSON must not fail or lose data during CSV output.
test "$("$@" -c "SELECT list(amount ORDER BY amount) AS amounts FROM read_json('fixture.json') WHERE category = 'alpha';")" = 'amounts
"[2, 40]"'
# Shell substitutions cannot carry a NUL byte; compare the public output's checksum.
test "$("$@" -c "SELECT 'a' || chr(0) || 'b' AS nul;" | cksum)" = "$(printf 'nul\na\000b\n' | cksum)"
# Write to an isolated path, and read it back through a fresh invocation.
parquet=$(mktemp ./ashell-duckdb.XXXXXXXX)
trap 'rm -f "$parquet"' EXIT
"$@" -c "COPY (SELECT * FROM read_csv('fixture.csv')) TO '$parquet' (FORMAT PARQUET);" >/dev/null
test "$("$@" -c "SELECT category, SUM(amount)::BIGINT AS total FROM read_parquet('$parquet') GROUP BY category ORDER BY category;")" = "$expected"

test "$("$@" -c 'SELECT 1 AS first; SELECT 2 AS second;')" = 'first
1'
if "$@" -c 'SELECT 1; SELECT missing FROM nowhere;' >/dev/null; then
    echo 'Invalid SQL in a later statement unexpectedly succeeded' >&2
    exit 1
fi
test "$("$@" -c 'SELECT 7 AS recovered;')" = 'recovered
7'
