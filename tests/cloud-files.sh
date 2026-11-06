#!/bin/sh
# Run through a-Shell's Dash in a disposable working directory.
cloud_files_contract() {
    mkdir -p cloud-fixture/.hidden/nested || return 1
    printf 'cloud-local-contract\n' > cloud-fixture/.hidden/nested/local.txt
    downloadFile cloud-fixture/.hidden/nested/local.txt || return 1
    downloadFolder -r cloud-fixture || return 1
    downloadFile --wait -- cloud-fixture/.hidden/nested/local.txt || return 1
    downloadFolder -w -r -- cloud-fixture || return 1
    downloadFolder cloud-fixture/.hidden/nested/local.txt > cloud-not-directory.out 2> cloud-not-directory.err
    test "$?" != 0 || return 1
    downloadFolder cloud-fixture/missing-folder > cloud-missing-folder.out 2> cloud-missing-folder.err
    test "$?" != 0 || return 1
    downloadFile cloud-fixture/missing.txt > cloud-missing.out 2> cloud-missing.err
    test "$?" != 0 || return 1
    test -s cloud-missing.err || return 1
    # A synthetic placeholder cannot download, but must be reached inside hidden folders.
    touch cloud-fixture/.hidden/nested/.remote.txt.icloud
    downloadFolder cloud-fixture > cloud-shallow.out 2> cloud-shallow.err || return 1
    downloadFolder -r --wait cloud-fixture > cloud-recursive.out 2> cloud-recursive.err
    test "$?" != 0 || return 1
    grep -q 'remote.txt' cloud-recursive.err || return 1
    downloadFolder -r cloud-fixture > cloud-default-recursive.out 2> cloud-default-recursive.err
    test "$?" != 0 || return 1
    grep -q 'remote.txt: ' cloud-default-recursive.err || return 1
    test -f cloud-fixture/.hidden/nested/.remote.txt.icloud || return 1
    test "$(cat cloud-fixture/.hidden/nested/local.txt)" = cloud-local-contract || return 1
    rm cloud-fixture/.hidden/nested/.remote.txt.icloud || return 1
    # Re-entry must work after an error without restarting the app.
    downloadFolder -r cloud-fixture || return 1
    printf 'dash-name\n' > ./-cloud-local.txt
    downloadFile -- -cloud-local.txt || return 1
    rm ./-cloud-local.txt || return 1
    downloadFile --unknown cloud-fixture > cloud-option.out 2> cloud-option.err
    test "$?" != 0 || return 1
    printf 'CLOUD_FILES_GREEN\n'
}
cloud_files_contract
