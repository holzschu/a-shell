# Run only when the fixture's face is already available independently of Documents/Fonts.
set -u
fixture="$HOME/Documents/Fonts/Fixture.ttf"
backup="$HOME/Documents/fonts-existing-fixture.ttf"
test -f "$fixture" || exit 1
test ! -e "$backup" || exit 1
restore_fixture() {
    if test -f "$backup"; then mv "$backup" "$fixture"; fi
}
trap restore_fixture EXIT
status=0
config --fonts > ~/Documents/fonts-existing-list.txt 2> ~/Documents/fonts-existing-errors.txt || status=1
test ! -s ~/Documents/fonts-existing-errors.txt || status=1
grep -q '^JetBrainsMonoNFM-Regular$' ~/Documents/fonts-existing-list.txt || status=1
config -n Fixture.ttf --show > ~/Documents/fonts-existing-alias.txt || status=1
grep -q 'JetBrainsMonoNFM-Regular' ~/Documents/fonts-existing-alias.txt || status=1
mv "$fixture" "$backup" || exit 1
config --fonts > ~/Documents/fonts-existing-removed.txt 2> ~/Documents/fonts-existing-removal-errors.txt || status=1
test ! -s ~/Documents/fonts-existing-removal-errors.txt || status=1
config -n JetBrainsMonoNFM-Regular --show > ~/Documents/fonts-existing-selected.txt || status=1
grep -q 'JetBrainsMonoNFM-Regular' ~/Documents/fonts-existing-selected.txt || status=1
restore_fixture
config --fonts > ~/Documents/fonts-existing-restored.txt 2> ~/Documents/fonts-existing-restore-errors.txt || status=1
test ! -s ~/Documents/fonts-existing-restore-errors.txt || status=1
grep -q '^JetBrainsMonoNFM-Regular$' ~/Documents/fonts-existing-restored.txt || status=1
printf '%s\n' "$status" > ~/Documents/fonts-existing-status.txt
if test "$status" -eq 0; then printf 'complete\n' > ~/Documents/fonts-existing-complete.txt; fi
exit "$status"
