# WebAssembly standard output redirection

`wasm-output.c` alternates writes to stdout and stderr. Build it on the host and copy `wasm-output.wasm` to the app's `Documents`:

```sh
uv run --with ziglang==0.16.0 python -m ziglang cc -target wasm32-wasi -O2 wasm-output.c -o wasm-output.wasm
```

In the a-Shell terminal, which runs `wasm` through the WebView, run:

```sh
cd ~/Documents
wasm wasm-output.wasm > combined.txt 2>&1
wasm wasm-output.wasm > stdout.txt 2> stderr.txt
```

`combined.txt` must contain `out-1`, `err-1`, `out-2`, `err-2` on four lines, in that order. `stdout.txt` must contain `out-1` and `out-2`, and `stderr.txt` must contain `err-1` and `err-2`. Before the fix, `combined.txt` contains only `err-1` and `err-2`: each stream wrote from its own offset, so the stderr lines overwrote the stdout lines.
