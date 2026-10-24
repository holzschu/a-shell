#!/bin/sh
# Host verifier: run after separate native photos and stat commands complete.
# Usage: initial|changed expected.json receipts copied-cache native-stat.txt
# Preserve the native photos stdout as receipts/<stage>-root.txt.
# Native stat format: %N|%i|%m|%z|%Lp, one record per original.
# expected.json maps A, B and C to the SHA256 of their synthetic PNG originals.
photos_membership() {
    test "$#" = 5 || return 2
    stage=$1
    expected=$2
    receipts=$3
    case "$stage" in initial|changed) ;; *) return 2 ;; esac
    mkdir -p "$receipts" || return 1
    python3 -I - "$stage" "$expected" "$receipts" "$4" "$5" <<'PY'
import collections
import hashlib
import json
import os
import pathlib
import stat
import sys

stage, expected_path, receipts_path, cache_path, metadata_path = sys.argv[1:]
native_root = pathlib.Path((pathlib.Path(receipts_path) / (stage + "-root.txt")).read_text().strip())
expected = json.loads(pathlib.Path(expected_path).read_text())
assert set(expected) == {"A", "B", "C"}, "Expected three named fixture hashes"
assert len(set(expected.values())) == 3, "Fixture hashes must differ"
selected = ["A", "B"] if stage == "initial" else ["B", "C"]
root = pathlib.Path(cache_path)
assert root.is_dir() and not root.is_symlink(), "Missing Photos cache"
metadata = {}
for line in pathlib.Path(metadata_path).read_text().splitlines():
    name, inode, mtime, size, mode = line.rsplit("|", 4)
    relative = str(pathlib.Path(name).relative_to(native_root))
    assert relative not in metadata, "Duplicate native stat record"
    assert int(mode, 8) == 0o400, "Original must be read-only on the device"
    metadata[relative] = {"inode": int(inode), "mtime": int(mtime), "size": int(size)}
files = []
for directory in root.iterdir():
    if directory.name.startswith("."):
        continue
    assert directory.is_dir() and not directory.is_symlink(), "Unexpected cache entry"
    for file in directory.iterdir():
        info = file.lstat()
        assert stat.S_ISREG(info.st_mode), "Original must be a regular file"
        relative = str(file.relative_to(root))
        native = metadata[relative]
        assert info.st_size == native["size"], "Copied original size differs"
        digest = hashlib.sha256(file.read_bytes()).hexdigest()
        files.append({"sha256": digest, "path": relative, **native})
assert set(metadata) == {item["path"] for item in files}, "Native stat and cache file lists differ"
assert collections.Counter(item["sha256"] for item in files) == collections.Counter(expected[name] for name in selected), "Cache does not contain exactly the selected originals"
by_hash = {item["sha256"]: item for item in files}
receipts = pathlib.Path(receipts_path)
if stage == "changed":
    previous = json.loads((receipts / "initial.json").read_text())
    assert previous["selected"] == ["A", "B"], "Missing initial selection receipt"
    old = {item["sha256"]: item for item in previous["files"]}
    assert by_hash[expected["B"]] == old[expected["B"]], "Unchanged B was rewritten"
    assert expected["A"] not in by_hash and expected["C"] not in old, "Selection did not change"
    assert not (root / old[expected["A"]]["path"]).exists(), "Removed A remains cached"
receipt = {"stage": stage, "selected": selected, "files": files, "result": "PASS"}
(receipts / (stage + ".json")).write_text(json.dumps(receipt, indent=2) + "\n")
print("PHOTOS_MEMBERSHIP_" + stage.upper() + "_GREEN selected=" + ",".join(selected) + " originals=2")
PY
}
photos_membership "$@"
