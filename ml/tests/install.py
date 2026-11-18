#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "rich"]
# ///
"""Exercise the native installer CLI and public version lease API over HTTP."""

import copy
import fcntl
import functools
import hashlib
import http.server
import io
import json
import os
import platform
import shutil
import signal
import subprocess
import tarfile
import tempfile
import threading
import time
from pathlib import Path

import typer
from rich.console import Console

app = typer.Typer()
console = Console(stderr=True)


class Fixture(http.server.SimpleHTTPRequestHandler):
    started = threading.Event()
    release = threading.Event()

    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path == "/slow.asmodel":
            data = (Path(self.directory) / "slow.asmodel").read_bytes()
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            try:
                self.wfile.write(data[:1024])
                self.wfile.flush()
                self.started.set()
                self.release.wait(20)
                self.wfile.write(data[1024:])
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            super().do_GET()


@app.command()
def check(command: Path, source: Path, image: Path, receipt: Path):
    image = image.resolve()
    assert image.is_file() and len(image.read_bytes()) == 784, "Pass the package-side known-answer image"
    command = command.resolve()
    source = source.resolve()
    evidence = []
    with tempfile.TemporaryDirectory(
        prefix="asml-install-", dir="/private/tmp"
    ) as scratch:
        root = Path(scratch)
        handler = functools.partial(Fixture, directory=root)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            base = f"http://127.0.0.1:{server.server_port}"
            ml = Path(__file__).resolve().parents[1]
            with tarfile.open(source) as archive:
                members = [(entry, archive.extractfile(entry).read() if entry.isfile() else None) for entry in archive]
            template = json.loads(members[0][1])
            assert template["package_format"] == "ashell-model-ustar-v1"
            identities = {}
            env = dict(os.environ, CFFIXED_USER_HOME=str(root / "home"))

            def run(*args, expected=0, extra=None):
                argv = [str(command), *args]
                result = subprocess.run(
                    argv,
                    env=env | (extra or {}),
                    capture_output=True,
                    text=True,
                    timeout=120,
                    check=False,
                )
                record = {
                    "argv": argv,
                    "exit": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                }
                evidence.append(record)
                console.print(
                    f"exit={result.returncode} {' '.join(args)}", markup=False
                )
                assert result.returncode == expected, record
                return json.loads(result.stdout if expected == 0 else result.stderr)

            def manifest(name, **changes):
                plan = copy.deepcopy(template)
                plan.update(changes)
                plan["version"] = name
                data = json.dumps(plan).encode()
                target = root / f"{name}.asmodel"
                with tarfile.open(target, "w", format=tarfile.USTAR_FORMAT) as archive:
                    for original, body in members:
                        entry = copy.copy(original)
                        if entry.name == "manifest.json":
                            body = data
                        entry.size = len(body or b"")
                        archive.addfile(entry, io.BytesIO(body) if body is not None else None)
                digest = hashlib.sha256(target.read_bytes()).hexdigest()
                identities[digest] = hashlib.sha256(data).hexdigest()
                return ["install", base + f"/{name}.asmodel", "--sha256", digest]

            rejected = run("install", "--manifest", str(source), "--sha256", hashlib.sha256(source.read_bytes()).hexdigest(), expected=2)
            assert "Usage:" in rejected["error"], rejected
            first = manifest("first")
            installed = run(*first)
            assert installed["validation_label"] == "7"
            assert (
                installed["source_sha256"]
                == template["source_sha256"]
            )
            version_dir = Path(installed["path"])
            # Brief external status/collection locks must not fail inference.
            with (version_dir.parent / ".install-lock").open("rb") as lock:
                fcntl.flock(lock, fcntl.LOCK_SH)
                release = threading.Timer(0.15, fcntl.flock, (lock, fcntl.LOCK_UN))
                release.start()
                try:
                    assert run("predict", "mnist", str(image))["runs"][0]["label"] == "7"
                finally:
                    release.join()
            times = {str(p): p.stat().st_mtime_ns for p in version_dir.rglob("*")}
            assert run(*first) == installed
            assert times == {
                str(p): p.stat().st_mtime_ns for p in version_dir.rglob("*")
            }
            run("run", "mnist", str(image), "--repeat", "2")

            def unchanged():
                assert run("ls")["manifest_sha256"] == installed["manifest_sha256"]

            # Native consumers do not expand shell variables in a local path.
            run(
                "install",
                "$HOME/Documents/missing.asmodel",
                "--sha256",
                first[-1],
                expected=2,
            )
            stopped = run("install-status", "mnist")
            assert (
                stopped["phase"] == "downloading" and stopped["command_running"] is False
            )
            unchanged()
            assert (
                run(*first) == installed
            )  # A stale checkpoint never holds the install lock.

            run(*first[:-1], "0" * 64, expected=2)
            for name, changes in [
                ("wrong-sha", {"source_sha256": "0" * 64}),
                ("wrong-size", {"source_bytes": 395694}),
                (
                    "archive-traversal",
                    {"archive": {"url": base + "/bad.zip", "members": ["../escape"]}},
                ),
                (
                    "archive-symlink",
                    {
                        "archive": {
                            "url": base + "/bad.zip",
                            "members": [{"path": "link", "target": "/tmp"}],
                        }
                    },
                ),
                ("schema", {"schema": 2}),
                ("runtime", {"runtime": "MLX"}),
                ("profile-type", {"memory_profile": None}),
                ("disk", {"disk_estimate_bytes": 9_000_000_000_000_000_000}),
            ]:
                run(*manifest(name, **changes), expected=75 if name == "disk" else 2)
                unchanged()
            # Corrupt actual HTTP archive bytes while retaining the caller's pin.
            for name, truncate in (("corrupt-body", False), ("short-body", True)):
                args = manifest(name)
                target = root / f"{name}.asmodel"
                data = target.read_bytes()
                target.write_bytes(data[:-1] if truncate else b"invalid" + data[7:])
                run(*args, expected=2)
                unchanged()

            # Crash the consumer after real POSIX writes, with no installer test switch.
            for phase in ["downloading", "compiling", "activating", "published"]:
                args = manifest("crash-" + phase)
                fault_env = env | {
                    "DYLD_INSERT_LIBRARIES": str(
                        command.parent / "install-faults.dylib"
                    ),
                    "ASML_FIXTURE_STOP": phase,
                }
                child = subprocess.Popen(
                    [str(command), *args],
                    env=fault_env,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    pid, state = os.waitpid(child.pid, os.WNOHANG | os.WUNTRACED)
                    if pid:
                        assert os.WIFSTOPPED(state), (phase, state)
                        break
                    time.sleep(0.01)
                else:
                    child.kill()
                    raise AssertionError(f"No filesystem fault stop for {phase}")
                if phase == "published":
                    state = run("install-status", "mnist")
                    run("cancel-install", "mnist", state["generation"], expected=75)
                child.kill()
                stdout, stderr = child.communicate(timeout=10)
                evidence.append(
                    {
                        "argv": [str(command), *args],
                        "fault": phase,
                        "exit": child.returncode,
                        "stdout": stdout,
                        "stderr": stderr,
                    }
                )
                assert child.returncode == -signal.SIGKILL
                if phase == "published":
                    assert run("ls")["manifest_sha256"] == identities[args[-1]]
                else:
                    unchanged()
                recovered = run(*args)
                assert recovered["manifest_sha256"] == identities[args[-1]]
                installed = recovered

            # Acknowledge cancellation after validation, just before publication.
            late = manifest("late-cancel")
            child = subprocess.Popen(
                [str(command), *late],
                env=env
                | {
                    "DYLD_INSERT_LIBRARIES": str(
                        command.parent / "install-faults.dylib"
                    ),
                    "ASML_FIXTURE_STOP": "before-commit",
                },
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                pid, state = os.waitpid(child.pid, os.WNOHANG | os.WUNTRACED)
                if pid:
                    assert os.WIFSTOPPED(state), state
                    break
                time.sleep(0.01)
            else:
                child.kill()
                raise AssertionError("No precommit filesystem fault stop")
            state = run("install-status", "mnist")
            assert state["command_running"] is True
            run("cancel-install", "mnist", state["generation"])
            child.send_signal(signal.SIGCONT)
            stdout, stderr = child.communicate(timeout=10)
            evidence.append(
                {
                    "argv": [str(command), *late],
                    "fault": "late-cancel",
                    "exit": child.returncode,
                    "stdout": stdout,
                    "stderr": stderr,
                }
            )
            assert child.returncode == 130, (stdout, stderr)
            unchanged()

            # A slow external server lets cancellation run while the CLI is blocked.
            slow = manifest("cancelled")
            shutil.copyfile(root / "cancelled.asmodel", root / "slow.asmodel")
            slow[1] = base + "/slow.asmodel"
            Fixture.started.clear()
            Fixture.release.clear()
            child = subprocess.Popen(
                [str(command), *slow],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            assert Fixture.started.wait(20)
            state = run("install-status", "mnist")
            assert state["phase"] == "downloading"
            run("cancel-install", "mnist", state["generation"])
            stdout, stderr = child.communicate(timeout=10)
            evidence.append(
                {
                    "argv": [str(command), *slow],
                    "exit": child.returncode,
                    "stdout": stdout,
                    "stderr": stderr,
                }
            )
            assert child.returncode == 130, stderr
            unchanged()
            Fixture.release.set()
            next_args = manifest("after-cancel")
            installed = run(*next_args)
            run("cancel-install", "mnist", state["generation"], expected=2)
            unchanged()
            previous = run("rollback", "mnist")
            assert previous["manifest_sha256"] != installed["manifest_sha256"]
            assert (
                run("rollback", "mnist")["manifest_sha256"]
                == installed["manifest_sha256"]
            )

            # A real API consumer holds the immutable old version across two updates.
            lease = subprocess.Popen(
                [str(command.parent / "lease")],
                env=env,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            held = json.loads(lease.stdout.readline())
            old_path = Path(held["path"])
            assert held["manifest_sha256"] == installed["manifest_sha256"]
            installed = run(*manifest("leased-update-one"))
            installed = run(*manifest("leased-update-two"))
            assert old_path.is_dir()
            run("remove", "mnist", expected=75)
            lease.stdin.close()
            assert lease.wait(timeout=10) == 0
            assert not old_path.exists()
            run(*manifest("gc-update"))
            assert not old_path.exists()

            # Backup restore may retain a record without the excluded files.
            installed = run("ls")
            (Path(installed["path"]) / "package" / template["model"]).unlink()
            error = run("ls", expected=2)
            assert "download again" in error["error"]
            run(*manifest("gc-update"))


        finally:
            Fixture.release.set()
            server.shutdown()
            server.server_close()
            receipt.write_text(
                json.dumps(
                    {
                        "commands": evidence,
                        "source_commit": subprocess.run(
                            ["git", "-C", str(ml.parent), "rev-parse", "HEAD"],
                            capture_output=True,
                            text=True,
                            check=True,
                        ).stdout.strip(),
                        "source_dirty": bool(
                            subprocess.run(
                                ["git", "-C", str(ml.parent), "diff", "--quiet"],
                                check=False,
                            ).returncode
                        ),
                        "macos": platform.mac_ver()[0],
                        "compiler": subprocess.run(
                            ["xcrun", "clang", "--version"],
                            capture_output=True,
                            text=True,
                            check=True,
                        ).stdout.strip(),
                        "source_sha256": hashlib.sha256(
                            source.read_bytes()
                        ).hexdigest(),
                        "runtime_sha256": hashlib.sha256(
                            command.read_bytes()
                        ).hexdigest(),
                    },
                    indent=2,
                )
                + "\n"
            )
    print("COREML_INSTALL_PASS")


if __name__ == "__main__":
    app()
