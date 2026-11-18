#!/bin/bash
# Qualify the public host service, package, tokenizer contract and same-process cancellation.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=${1:?Usage: embedding-host.sh OWNED_OUTPUT MODEL_ID PACKAGE REFERENCE TOKENIZER PRECISION}
model=${2:?Model id required}
package=${3:?Package required}
reference=${4:?Frozen reference required}
tokenizer=${5:?Original pinned tokenizer.json required}
precision=${6:?float32, float16 or int8 required}
test ! -e "$out" || { echo 'Choose a new output directory' >&2; exit 2; }
mkdir -p "$out"
out=$(cd "$out" && pwd)
bash "$root/build.sh" --host "$out/runtime"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -I"$root" "$root/AShellEmbedding.m" "$root/tests/embedding-tokenizer.m" -framework Foundation -framework CoreML -o "$out/tokenizer"
"$out/tokenizer" "$root/models/embedding-tokenizers.json" "$model" "$tokenizer" > "$out/tokenizer.stdout" 2> "$out/tokenizer.stderr"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -I"$root" -c "$root/tests/embedding-session.m" -o "$out/session.o"
objects=()
for name in AShellML AShellMLInstall AShellMLJob AShellEmbedding; do objects+=("$out/runtime/objects/$name.o"); done
xcrun clang "${objects[@]}" "$out/session.o" -framework Foundation -framework CoreML -framework CoreVideo -framework Accelerate -o "$out/session"
export CFFIXED_USER_HOME="$out/home"
digest=$(shasum -a 256 "$package" | cut -d ' ' -f 1)
"$out/runtime/coreml" install "$model" "$package" --sha256 "$digest" > "$out/install.stdout" 2> "$out/install.stderr"
uv run "$root/tests/embeddings.py" "$out/runtime/coreml" "$model" "$reference" "$out/cli" --precision "$precision" > "$out/cli.stdout" 2> "$out/cli.stderr"
# Generate bounded consumer inputs; only standard-library Python is needed here.
cp "$out/cli/case-0.input.json" "$out/recovery.json"
python3 - "$out" "$root/models/embedding-corpus.json" "$model" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
corpus = json.loads(Path(sys.argv[2]).read_bytes())
long = {"texts": ["The English fixture must remain cancellable during a sequential embedding batch. " * 4] * 256}
(root / "long.json").write_text(json.dumps(long))
phone = root / "phone"
phone.mkdir()
query = {"texts": corpus["queries"]}
if sys.argv[3].startswith("qwen"):
    query["instruction"] = corpus["instruction"]
inputs = {"validation-input": json.loads((root / "recovery.json").read_bytes()), "documents": {"texts":corpus["documents"]}, "queries":query, "truncated":{"texts":["hello "*150],"truncate":True}, "empty":{"texts":[]}, "bad-type":{"texts":[1]}, "overlength":{"texts":["hello "*150]}, "long":long}
for name, request in inputs.items():
    (phone / (name + ".json")).write_text(json.dumps(request, ensure_ascii=False))
(phone / "malformed.json").write_text('{"texts":')
PY
cp "$root/tests/embedding-phone.sh" "$out/phone/embedding-phone.sh"
"$out/session" "$model" "$out/long.json" "$out/recovery.json" > "$out/session.stdout" 2> "$out/session.stderr"
shasum -a 256 "$out/runtime/coreml" "$out/session" "$package" "$reference" "$tokenizer" > "$out/sha256.txt"
echo EMBEDDING_HOST_PASS
