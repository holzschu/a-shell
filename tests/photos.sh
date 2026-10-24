#!/bin/sh
# Run in a disposable working directory after the user answers the Photos prompt.
photos_contract() {
    photos > photos-root.txt 2> photos-first.err || return 1
    root=$(cat photos-root.txt)
    test -f "$root/.photos-index.json" || return 1
    ls "$root" > photos-list.txt || return 1
    find "$root" -type f > photos-find.txt || return 1
    originals=0
    video_checked=0
    : > photos-before.txt
    for file in "$root"/*/*; do
        test -f "$file" || continue
        test ! -w "$file" || return 1
        if test "$originals" = 0; then
            rm -f photos-copy.original || return 1
            cp "$file" photos-copy.original || return 1
            test "$(cksum < "$file")" = "$(cksum < photos-copy.original)" || return 1
        fi
        case "$file" in
            *.MOV|*.mov|*.MP4|*.mp4)
                if test "$video_checked" = 0; then
                    ffprobe -v error -show_entries format=format_name "$file" > photos-video.txt 2> photos-video.err || return 1
                    video_checked=1
                fi
                ;;
        esac
        originals=$((originals + 1))
        stat -f '%N %i %m %z %Sp' "$file" >> photos-before.txt || return 1
    done
    test "$originals" != 0 || return 1
    test -s photos-before.txt || return 1
    photos > photos-root-repeat.txt 2> photos-repeat.err || return 1
    test "$(cat photos-root-repeat.txt)" = "$root" || return 1
    : > photos-after.txt
    for file in "$root"/*/*; do
        test -f "$file" || continue
        stat -f '%N %i %m %z %Sp' "$file" >> photos-after.txt || return 1
    done
    test -s photos-after.txt || return 1
    test "$(cksum < photos-before.txt)" = "$(cksum < photos-after.txt)" || return 1
    printf 'PHOTOS_GREEN originals=%s video_checked=%s\n' "$originals" "$video_checked"
}
photos_contract
