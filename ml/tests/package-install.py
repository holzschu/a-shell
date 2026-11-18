#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "rich"]
# ///
"""Qualify S4 archives through the native installer CLI."""

import copy
import functools
import hashlib
import http.server
import io
import json
import os
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


@app.command()
def check(command: Path, fixtures: Path, receipt: Path):
    command, fixtures = command.resolve(), fixtures.resolve()
    evidence = []
    with tempfile.TemporaryDirectory(
        prefix="asml-package-", dir="/private/tmp"
    ) as scratch:
        env = dict(os.environ, CFFIXED_USER_HOME=scratch)
        root = Path(scratch)
        snapshot = root / "fixtures"
        for name in (
            "first/mnist.asmodel",
            "program/mnist.asmodel",
            "bad-feature.asmodel",
            "bad-hash.asmodel",
            "oversize.asmodel",
            "wrong-model-feature.mlmodel",
        ):
            target = snapshot / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(fixtures / name, target)
        fixtures = snapshot

        def run(*args, expected=0):
            argv = [str(command), *map(str, args)]
            result = subprocess.run(
                argv, env=env, capture_output=True, text=True, timeout=120, check=False
            )
            evidence.append(
                {
                    "argv": argv,
                    "exit": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                }
            )
            receipt.parent.mkdir(parents=True, exist_ok=True)
            receipt.write_text(json.dumps(evidence, indent=2) + "\n")
            assert result.returncode == expected, evidence[-1]
            return json.loads(result.stdout if expected == 0 else result.stderr)

        package = fixtures / "first/mnist.asmodel"
        digest = hashlib.sha256(package.read_bytes()).hexdigest()
        installed = run("install", package, "--sha256", digest)
        assert installed["source_bytes"] == 31823
        assert installed["validation_label"] == "7"
        assert installed["archive_sha256"] == digest
        assert installed["package_format"] == "ashell-model-ustar-v1"
        first = installed["manifest_sha256"]
        before = Path(installed["path"]).stat().st_mtime_ns
        assert run("install", "mnist", package)["manifest_sha256"] == first
        assert Path(installed["path"]).stat().st_mtime_ns == before
        assert (
            run("run", "mnist", Path(__file__).with_name("seven.gray"))["runs"][0][
                "label"
            ]
            == "7"
        )
        run("unload")
        program = run("install", fixtures / "program/mnist.asmodel")
        assert program["model"].endswith(".mlpackage")
        assert program["manifest_sha256"] != first
        assert (
            run("run", "mnist", Path(__file__).with_name("seven.gray"))["runs"][0][
                "label"
            ]
            == "7"
        )
        run("unload")
        assert run("rollback", "mnist")["manifest_sha256"] == first

        for case in ("bad-feature", "bad-hash", "oversize"):
            run("install", fixtures / f"{case}.asmodel", expected=2)
            assert run("ls")["manifest_sha256"] == first
        run("install", package, "--sha256", "0" * 64, expected=2)
        run("install", package, "--sha256", "bad", expected=2)
        link = root / "local-symlink.asmodel"
        link.symlink_to(package)
        run("install", link, expected=2)

        with tarfile.open(package) as archive:
            originals = [
                (entry, archive.extractfile(entry).read()) for entry in archive
            ]

        def changed(name, entries):
            target = root / f"{name}.asmodel"
            with tarfile.open(target, "w", format=tarfile.USTAR_FORMAT) as archive:
                for entry, data in entries:
                    archive.addfile(entry, io.BytesIO(data))
            return target

        for case in (
            "duplicate",
            "unknown",
            "missing",
            "symlink",
            "hardlink",
            "absolute",
            "traversal",
            "backslash",
            "pax",
            "sparse",
            "manifest-last",
        ):
            entries = copy.deepcopy(originals)
            if case == "duplicate":
                entries.append(copy.deepcopy(entries[1]))
            elif case == "missing":
                entries.pop()
            elif case == "manifest-last":
                entries.reverse()
            elif case in ("unknown", "absolute", "traversal", "backslash"):
                entries[1][0].name = {
                    "unknown": "unknown.mlmodel",
                    "absolute": "/escape.mlmodel",
                    "traversal": "../escape.mlmodel",
                    "backslash": "..\\escape.mlmodel",
                }[case]
            else:
                entry = entries[1][0]
                entry.type = {
                    "symlink": tarfile.SYMTYPE,
                    "hardlink": tarfile.LNKTYPE,
                    "pax": tarfile.XHDTYPE,
                    "sparse": tarfile.GNUTYPE_SPARSE,
                }[case]
                entry.linkname = "outside"
            run("install", changed(case, entries), expected=2)
            assert run("ls")["manifest_sha256"] == first

        for case in (
            "task",
            "member-limit",
            "archive-limit",
            "model-receipt",
            "manifest-object",
            "disk",
            "compiled-feature",
        ):
            entries = copy.deepcopy(originals)
            plan = json.loads(entries[0][1])
            if case == "task":
                plan["task"] = "unsupported-task"
            elif case == "member-limit":
                plan["limits"]["member_bytes"] = 1
            elif case == "archive-limit":
                plan["limits"]["archive_bytes"] = 1
            elif case == "model-receipt":
                plan["members"][plan["model"]] = "invalid"
            elif case == "disk":
                plan["disk_estimate_bytes"] = 2**62
            elif case == "compiled-feature":
                model = (fixtures / "wrong-model-feature.mlmodel").read_bytes()
                entry = entries[1][0]
                entry.size = len(model)
                entries[1] = (entry, model)
                plan["source_bytes"] = len(model)
                plan["source_sha256"] = hashlib.sha256(model).hexdigest()
                plan["members"][plan["model"]]["bytes"] = len(model)
                plan["members"][plan["model"]]["sha256"] = plan["source_sha256"]
            else:
                plan = []
            data = json.dumps(plan).encode()
            entries[0] = (entries[0][0], data)
            entries[0][0].size = len(data)
            run("install", changed(case, entries), expected=75 if case == "disk" else 2)

        raw = package.read_bytes()
        with tarfile.open(package) as archive:
            last = archive.getmembers()[-1]
            end = (last.offset_data + last.size + 511) // 512 * 512
        for case in ("checksum", "padding", "one-terminator", "trailing"):
            data = bytearray(raw)
            if case == "checksum":
                data[0] ^= 1
            elif case == "padding":
                data[512 + originals[0][0].size] = 1
            elif case == "one-terminator":
                data = data[: end + 512]
            else:
                data[-1] = 1
            target = root / f"{case}.asmodel"
            target.write_bytes(data)
            run("install", target, expected=2)

        assert hashlib.sha256(package.read_bytes()).hexdigest() == digest
        handler = functools.partial(
            http.server.SimpleHTTPRequestHandler, directory=fixtures
        )
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            assert (
                run(
                    "install",
                    f"http://127.0.0.1:{server.server_port}/first/mnist.asmodel",
                    "--sha256",
                    digest,
                )["manifest_sha256"]
                == first
            )
        finally:
            server.shutdown()
            server.server_close()
        assert run("install-status", "mnist")["command_running"] is False
        faults = command.parent / "install-faults.dylib"
        assert faults.is_file(), faults

        def versioned(name):
            entries = copy.deepcopy(originals)
            plan = json.loads(entries[0][1])
            plan["version"] = name
            data = json.dumps(plan).encode()
            entries[0] = (entries[0][0], data)
            entries[0][0].size = len(data)
            return changed(name, entries)

        def stopped_child(package_path, phase):
            child = subprocess.Popen(
                [str(command), "install", str(package_path)],
                env=env
                | {"DYLD_INSERT_LIBRARIES": str(faults), "ASML_FIXTURE_STOP": phase},
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                pid, state = os.waitpid(child.pid, os.WNOHANG | os.WUNTRACED)
                if pid:
                    assert os.WIFSTOPPED(state), (phase, state)
                    return child
                time.sleep(0.01)
            child.kill()
            child.communicate(timeout=10)
            raise AssertionError(f"No filesystem fault stop at {phase}")

        for phase in ("downloading", "compiling", "activating", "published"):
            old = run("ls")["manifest_sha256"]
            target = versioned("crash-" + phase)
            child = stopped_child(target, phase)
            assert run("install-status", "mnist")["command_running"] is True
            child.kill()
            stdout, stderr = child.communicate(timeout=10)
            evidence.append(
                {
                    "fault": phase,
                    "exit": child.returncode,
                    "stdout": stdout,
                    "stderr": stderr,
                }
            )
            assert child.returncode == -signal.SIGKILL
            observed = run("ls")["manifest_sha256"]
            assert (observed != old) if phase == "published" else (observed == old)
            assert run("install", target)["validation_label"] == "7"

        old = run("ls")["manifest_sha256"]
        target = versioned("cancel-before-commit")
        child = stopped_child(target, "before-commit")
        state = run("install-status", "mnist")
        run("cancel-install", "mnist", state["generation"])
        child.send_signal(signal.SIGCONT)
        stdout, stderr = child.communicate(timeout=30)
        evidence.append(
            {
                "fault": "cancel-before-commit",
                "exit": child.returncode,
                "stdout": stdout,
                "stderr": stderr,
            }
        )
        assert child.returncode == 130, evidence[-1]
        assert run("ls")["manifest_sha256"] == old
        recovered = run("install", target)
        assert recovered["validation_label"] == "7"
        assert {entry.name for entry in Path(recovered["path"]).iterdir()} == {
            "package", "model.mlmodelc", "manifest.json", "receipt.json", "plan.json"
        }, "Retry published transfer scratch files into the immutable version"
    console.print("COREML_PACKAGE_INSTALL_PASS")


if __name__ == "__main__":
    app()
