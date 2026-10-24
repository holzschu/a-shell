#!/bin/sh
# Run in a-Shell with a Nerd Font installed as Documents/Fonts/Fixture.ttf.
font_contract() {
    config --fonts > ~/Documents/fonts-list.txt 2> ~/Documents/fonts-errors.txt || return 1
    grep -q '^JetBrainsMonoNFM-Regular$' ~/Documents/fonts-list.txt || return 1
    config -n JetBrainsMonoNFM-Regular -s 17 -gp --show > ~/Documents/fonts-selected.txt 2>> ~/Documents/fonts-errors.txt || return 1
    grep -q 'JetBrainsMonoNFM-Regular 17.0 pt' ~/Documents/fonts-selected.txt || return 1
    if config -n FontThatDoesNotExist707 > ~/Documents/fonts-invalid.txt 2>> ~/Documents/fonts-errors.txt; then return 1; fi
    config --show > ~/Documents/fonts-after-invalid.txt
    diff ~/Documents/fonts-selected.txt ~/Documents/fonts-after-invalid.txt || return 1
    printf 'not a font\n' > ~/Documents/Fonts/Broken707.ttf || return 1
    config --fonts > /dev/null 2> ~/Documents/fonts-format-errors.txt
    rm ~/Documents/Fonts/Broken707.ttf || return 1
    grep -q 'com.apple.CoreText.CTFontManagerErrorDomain:104' ~/Documents/fonts-format-errors.txt || return 1
    grep -q 'CTFontManagerErrorFontURLs' ~/Documents/fonts-format-errors.txt || return 1
    config -n Fixture.ttf --show > ~/Documents/fonts-file.txt || return 1
    grep -q 'JetBrainsMonoNFM-Regular 17.0 pt' ~/Documents/fonts-file.txt || return 1
    mv ~/Documents/Fonts/Fixture.ttf ~/Documents/Fixture.ttf.saved || return 1
    config --fonts > ~/Documents/fonts-removed-list.txt 2> ~/Documents/fonts-removal-errors.txt
    removal_status=0
    if grep -q '^JetBrainsMonoNFM-Regular$' ~/Documents/fonts-removed-list.txt; then removal_status=1; fi
    if config -n JetBrainsMonoNFM-Regular 2>> ~/Documents/fonts-removal-errors.txt; then removal_status=1; fi
    mv ~/Documents/Fixture.ttf.saved ~/Documents/Fonts/Fixture.ttf || return 1
    config --fonts > ~/Documents/fonts-restored-list.txt 2> ~/Documents/fonts-restore-errors.txt
    config -n JetBrainsMonoNFM-Regular --show > ~/Documents/fonts-restored.txt || return 1
    if [ "$removal_status" != 0 ]; then return 1; fi
    grep -q 'JetBrainsMonoNFM-Regular 17.0 pt' ~/Documents/fonts-restored.txt || return 1
    printf 'Powerline: \356\202\260 \356\202\262  Icons: \357\204\240 \357\200\223\n'
    printf 'complete\n' > ~/Documents/fonts-complete.txt
}
font_contract
