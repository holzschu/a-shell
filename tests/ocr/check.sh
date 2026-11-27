#!/bin/sh
# Copy this directory into a-Shell's Documents and run: sh ocr/check.sh
set -eu
cd "$(dirname "$0")"

status=0
ocr -l ru,en 'bilingual text.png' > png.out 2> png.err || status=$?
printf '%s\n' "$status" > png.status
[ "$status" -eq 0 ]
[ ! -s png.err ]
printf '%s\n' 'Hello from Apple Vision' 'Распознавание текста' > bilingual.expected
diff -u bilingual.expected png.out

ocr -l ru,en 'two pages.pdf' > pdf.out 2> pdf.err
[ ! -s pdf.err ]
diff -u bilingual.expected pdf.out

status=0
ocr does-not-exist.png > missing.out 2> missing.err || status=$?
printf '%s\n' "$status" > missing.status
[ "$status" -eq 1 ]
[ ! -s missing.out ]
grep -q 'ocr: does-not-exist.png:' missing.err

ocr --fast -- english.jpg english.heic > fast.out 2> fast.err
[ ! -s fast.err ]
printf '%s\n' 'Hello from Apple Vision' 'Hello from Apple Vision' > english.expected
diff -u english.expected fast.out

printf '%s\n' 'PASS: native ocr' > result
