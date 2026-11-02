#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "rich"]
# ///
"""Check real Codex exec tool results against a local Responses fixture."""

import gzip
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import typer
from rich.console import Console
from rich.markup import escape

console = Console(stderr=True)
app = typer.Typer()

# Each command crosses the actual native/WASM dispatcher in the app, without
# substituting ios_system, descriptor cleanup, or Codex's tool implementation.
CASES = [
    ("wasm-stdout", "mktemp -d ./transport-XXXXXX", "./transport-", 0),
    ("wasm-stderr", "mktemp -d /dev/null/transport-XXXXXX", "/dev/null/transport-", 1),
    ("native-status", "printf 'NATIVE_STATUS_OK\\n'; \\exit 7", "NATIVE_STATUS_OK", 7),
    ("native-stderr", "ls ./transport-native-missing-entry", "transport-native-missing-entry", 1),
    ("wasm-pipeline", "mktemp -d ./transport-pipe-XXXXXX | cat", "./transport-pipe-", 0),
    ("recovery", "printf 'TRANSPORT_RECOVERY_OK\\n'", "TRANSPORT_RECOVERY_OK", 0),
]


def serve(output: Path) -> bool:
    output.mkdir(parents=True, exist_ok=False)
    receipt = {}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            raw = self.rfile.read(int(self.headers["Content-Length"]))
            if self.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            request = json.loads(raw)
            with (output / "requests.jsonl").open("a") as log:
                log.write(json.dumps(request) + "\n")
            replies = {
                item.get("call_id"): item.get("output", "")
                for item in request.get("input", [])
                if item.get("type") == "function_call_output"
            }
            checks = []
            for name, command, marker, status in CASES:
                if name not in replies:
                    item = {
                        "type": "function_call",
                        "call_id": name,
                        "name": "exec_command",
                        "arguments": json.dumps(
                            {"cmd": command, "tty": False, "yield_time_ms": 10000, "max_output_tokens": 1500}
                        ),
                    }
                    break
                result = replies[name]
                checks.append(
                    {
                        "case": name,
                        "expected_status": status,
                        "passed": marker in result
                        and f"Process exited with code {status}" in result
                        and "Native tool transport failed:" not in result,
                        "output": result,
                    }
                )
            else:
                receipt.update(passed=all(check["passed"] for check in checks), checks=checks)
                (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
                item = {
                    "type": "message",
                    "role": "assistant",
                    "id": "transport-result",
                    "content": [
                        {"type": "output_text", "text": "TRANSPORT_PASS" if receipt["passed"] else "TRANSPORT_FAIL"}
                    ],
                }
            events = [
                {"type": "response.created", "response": {"id": "transport-response"}},
                {"type": "response.output_item.done", "item": item},
                {
                    "type": "response.completed",
                    "response": {
                        "id": "transport-response",
                        "usage": {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0},
                    },
                },
            ]
            body = "".join("data: " + json.dumps(event) + "\n\n" for event in events).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            if receipt:
                threading.Thread(target=self.server.shutdown, daemon=True).start()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    base_url = f"http://127.0.0.1:{server.server_port}/v1"
    (output / "base-url.txt").write_text(base_url + "\n")
    print(json.dumps({"base_url": base_url}), flush=True)
    timeout = threading.Timer(180, server.shutdown)
    timeout.start()
    try:
        server.serve_forever()
    finally:
        timeout.cancel()
        server.server_close()
    return receipt.get("passed", False)


@app.command()
def main(output: Path):
    """Serve the fixture for a real app configured with requires_openai_auth=false."""
    try:
        passed = serve(output)
    except (OSError, ValueError) as error:
        console.print(f"[red]Error:[/] {escape(str(error))}")
        raise typer.Exit(1) from error
    raise typer.Exit(0 if passed else 1)


if __name__ == "__main__":
    try:
        app()
    except KeyboardInterrupt:
        raise SystemExit(130) from None
