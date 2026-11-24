#!/bin/sh
# Check the Xcode resource and command catalog inputs without building the app.
set -eu
cd "$(dirname "$0")/.."

case ${1:-} in
    catalog)
        work=$(mktemp -d)
        trap 'rm -r "$work"' EXIT
        for catalog in Resources/commandDictionary.plist Resources_mini/commandDictionary.plist; do
            plutil -convert json -o - "$catalog" | jq -e '
                [ .ssh[:2], .scp[:2], .sftp[:2], .["ssh-keygen"][:2] ] ==
                (["ssh_main", "scp_main", "sftp_main", "sshkeygen_main"] |
                    map(["ssh_cmd.framework/ssh_cmd", .]))
            ' >/dev/null || { echo "$catalog must provide legacy SSH" >&2; exit 1; }
        done
        SRCROOT=$PWD TARGET_BUILD_DIR=$work UNLOCALIZED_RESOURCES_FOLDER_PATH=worker \
            DERIVED_FILE_DIR=$work/derived ASHELL_WORKER_HOST_IDENTIFIER=test.a-Shell-mini \
            bash ShellWorkers/resources.sh
        plutil -convert json -o - "$work/worker/commandDictionary.plist" | jq -e '
            [ .ssh[:2], .scp[:2], .sftp[:2], .["ssh-keygen"][:2] ] ==
            (["ssh_main", "scp_main", "sftp_main", "sshkeygen_main"] |
                map(["@rpath/ssh_cmd.framework/ssh_cmd", .]))
        ' >/dev/null
        for name in ssh scp sftp ssh-keygen; do test -x "$work/worker/bin/$name"; done
        SRCROOT=$PWD TARGET_BUILD_DIR=$work UNLOCALIZED_RESOURCES_FOLDER_PATH=full-worker \
            DERIVED_FILE_DIR=$work/full-derived ASHELL_WORKER_HOST_IDENTIFIER=test.a-Shell \
            ASHELL_WORKER_COMMAND_CATALOG=Resources/commandDictionary.plist \
            bash ShellWorkers/resources.sh
        plutil -convert json -o - "$work/full-worker/commandDictionary.plist" | jq -e '
            has("node") and .ssh[:2] == ["@rpath/ssh_cmd.framework/ssh_cmd", "ssh_main"]
        ' >/dev/null
        test -x "$work/full-worker/bin/node"
        test ! -e "$work/worker/bin/node"
        grep -Fq 'Identifier(host: "test.a-Shell", name: "ShellWorker")' "$work/full-derived/Worker.swift"
        grep -Fq 'Identifier(host: "test.a-Shell-mini", name: "ShellWorker")' "$work/derived/Worker.swift"
        plutil -convert json -o - Resources_mini/sshStockCommands.plist | jq -e '
            keys == ["scp", "sftp", "ssh", "ssh-keygen"] and
            ([ .ssh[:2], .scp[:2], .sftp[:2], .["ssh-keygen"][:2] ] == [
                ["@rpath/SSHStock.framework/SSHStock", "ashell_ssh_main"],
                ["@rpath/SCPStock.framework/SCPStock", "ashell_scp_main"],
                ["@rpath/SFTPStock.framework/SFTPStock", "ashell_sftp_main"],
                ["@rpath/SSHKeygenStock.framework/SSHKeygenStock", "ashell_ssh_keygen_main"]
            ])
        ' >/dev/null
        ;;
    project)
        count=$(plutil -extract ShellWorkerCount raw -o - a-Shell-mini-Info.plist)
        plutil -convert json -o - a-Shell.xcodeproj/project.pbxproj | jq -e --argjson count "$count" '
            .objects as $o |
            def phase($kind): .buildPhases[] | $o[.] | select(.isa == $kind);
            def files: .files[] | $o[.] as $build | $o[$build.fileRef // ""].path;
            def stock: test("(^|/)(SSH|SCP|SFTP|SSHKeygen)Stock\\.xcframework$");
            [$o[] | select(.isa == "PBXNativeTarget")] as $targets |
            [$targets[] | select(.name | test("^ShellWorker[A-Z]$"))] as $workers |
            ($targets[] | select(.name == "a-Shell-mini")) as $mini |
            ($workers | length) == $count and
            ([$targets[] | select(any(phase("PBXResourcesBuildPhase") | files;
                . == "Resources_mini/sshStockCommands.plist")) | .name] | sort) ==
                ([$workers[].name, "a-Shell-mini"] | sort) and
            ([$mini | phase("PBXCopyFilesBuildPhase") | .files[] | $o[.] as $build |
                $o[$build.fileRef // ""].path // empty | select(stock) |
                select($build.settings.ATTRIBUTES | index("CodeSignOnCopy"))] | sort) ==
                ["xcfs/SCPStock.xcframework", "xcfs/SFTPStock.xcframework",
                 "xcfs/SSHKeygenStock.xcframework", "xcfs/SSHStock.xcframework"] and
            all($targets[] | select(.name != "a-Shell-mini");
                all(phase("PBXCopyFilesBuildPhase") | files // empty; stock | not)) and
            ([$mini | phase("PBXCopyFilesBuildPhase") | files // empty | split("/")[-1] |
                select(test("^ShellWorker[A-Z]\\.appex$"))] | sort) ==
                ([$workers[].name + ".appex"] | sort) and
            ([$mini.dependencies[] | $o[$o[.].target // ""].name // empty | select(test("^ShellWorker[A-Z]$"))] | sort) ==
                ([$workers[].name] | sort) and
            all($targets[] | select(.name | IN("a-Shell", "a-Shell-mini", "a-Shell-noPython"));
                any(phase("PBXSourcesBuildPhase") | files; . == "ExecuteLongCommandIntent.swift")) and
            all($targets[] | select(.name | IN("a-Shell", "a-Shell-Intents"));
                any(phase("PBXResourcesBuildPhase") | files; . == "Resources/commandDictionary.plist")) and
            all($targets[] | select(.name | IN("a-Shell-mini", "a-Shell-noPython", "a-Shell-mini-Intents"));
                any(phase("PBXResourcesBuildPhase") | files; . == "Resources_mini/commandDictionary.plist"))
        ' >/dev/null || { echo 'Incorrect Stock SSH resource or framework membership' >&2; exit 1; }
        ;;
    activation)
        # Pin both sides of the spawn request. Runtime version checks are in worker-pool.md.
        grep -Fq 'stockSSH:(BOOL)stockSSH' ShellWorkers/PaneWire.h
        grep -Fq 'stockSSH:ashell_stock_ssh_enabled()' ShellWorkers/RemotePane.m
        grep -Fq 'if (stockSSH && !NSProcessInfo.processInfo.iOSAppOnMac)' ShellWorkers/Worker.m
        if grep -Fq 'ASHELL_WORKER_COMMANDS' ShellWorkers/Worker.m; then
            echo 'Worker routing must not enable the Stock catalog' >&2
            exit 1
        fi
        ;;
    *) echo "usage: $0 catalog|project|activation" >&2; exit 2 ;;
esac
echo "Stock SSH $1 check passed"
