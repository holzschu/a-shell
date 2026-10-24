#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer>=0.16", "rich>=14"]
# ///
"""Audit native port products using Apple's tools, without changing them."""

import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console
from rich.markup import escape

cli = typer.Typer()
console = Console(stderr=True)
MAGIC = {
    b"\xfe\xed\xfa\xce",
    b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf",
    b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe",
    b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf",
    b"\xbf\xba\xfe\xca",
}


def run(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(args, text=True, capture_output=True, check=False, cwd=cwd)
    if result.returncode:
        raise ValueError(f"{args[0]} failed for {args[-1]}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def version(value: str) -> tuple[int, ...]:
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))


def within(root: Path, relative: str) -> Path:
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError(f"Path escapes artifact: {relative}")
    if not target.exists():
        raise ValueError(f"Missing artifact member: {relative}")
    return target


def audit_binary(binary: Path, platform: str, maximum: str, signed: bool) -> dict:
    architectures = run("xcrun", "lipo", "-archs", str(binary)).split()
    slices = []
    for arch in architectures:
        build = run("xcrun", "vtool", "-arch", arch, "-show-build", str(binary))
        platforms = re.findall(r"^\s*platform\s+(\S+)", build, re.MULTILINE)
        minimums = re.findall(r"^\s*minos\s+(\S+)", build, re.MULTILINE)
        # Pre-LC_BUILD_VERSION iOS products encode Simulator only through the x86 architecture.
        if not platforms and "cmd LC_VERSION_MIN_IPHONEOS" in build:
            platforms = ["IOSSIMULATOR" if arch in {"i386", "x86_64"} else "IOS"]
            minimums = re.findall(r"^\s*version\s+(\S+)", build, re.MULTILINE)
        if platforms != [platform] or len(minimums) != 1:
            raise ValueError(f"{binary} ({arch}): expected one {platform} build record, got {build.strip()}")
        if version(minimums[0]) > version(maximum):
            raise ValueError(f"{binary} ({arch}): minimum OS {minimums[0]} exceeds {maximum}")
        dependencies = []
        for line in run("xcrun", "otool", "-arch", arch, "-L", str(binary)).splitlines():
            if not line.startswith("\t"):
                continue
            dependency = line.strip().split(" (", 1)[0]
            if not dependency.startswith(
                ("/usr/lib/", "/System/Library/", "@rpath/", "@loader_path/", "@executable_path/")
            ):
                raise ValueError(f"{binary} ({arch}): nonportable dependency {dependency}")
            dependencies.append(dependency)
        slices.append({"arch": arch, "platform": platforms[0], "minos": minimums[0], "dependencies": dependencies})
    if signed:
        run("codesign", "--verify", "--strict", str(binary))
    with binary.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    return {
        "binary": str(binary),
        "sha256": digest,
        "slices": slices,
    }


def audit_framework(root: Path, maximum: str) -> list[dict]:
    with (root / "Info.plist").open("rb") as source:
        libraries = plistlib.load(source)["AvailableLibraries"]
    if not libraries:
        raise ValueError("Empty xcframework")
    rows, destinations = [], set()
    for library in libraries:
        if library["SupportedPlatform"] != "ios":
            raise ValueError("Only iOS xcframeworks are supported")
        variant = library.get("SupportedPlatformVariant", "device")
        platform = {"device": "IOS", "simulator": "IOSSIMULATOR", "maccatalyst": "MACCATALYST"}[variant]
        member = within(root, library["LibraryIdentifier"])
        product = within(member, library["LibraryPath"])
        if product.suffix != ".framework":
            raise ValueError(
                "Static archives require a recipe-specific member audit; this checker accepts dynamic frameworks"
            )
        with (product / "Info.plist").open("rb") as source:
            executable = plistlib.load(source)["CFBundleExecutable"]
        row = audit_binary(within(product, executable), platform, maximum, signed=False)
        actual = {item["arch"] for item in row["slices"]}
        if actual != set(library["SupportedArchitectures"]):
            raise ValueError(f"{product}: plist architectures differ from lipo")
        if any((variant, arch) in destinations for arch in actual):
            raise ValueError(f"{product}: duplicate platform/architecture")
        destinations.update((variant, arch) for arch in actual)
        rows.append(row)
    if ("device", "arm64") not in destinations or not any(item[0] == "simulator" for item in destinations):
        raise ValueError("Require arm64 device and at least one Simulator architecture")
    return rows


def audit_app(root: Path, maximum: str, platform: str) -> list[dict]:
    rows = []
    for candidate in sorted(root.rglob("*")):
        if not candidate.is_file() or ".dSYM" in "".join(candidate.relative_to(root).parts):
            continue
        within(root, str(candidate.relative_to(root)))
        with candidate.open("rb") as source:
            magic = source.read(4)
        if magic in MAGIC:
            rows.append(audit_binary(candidate, platform, maximum, signed=True))
    if not rows:
        raise ValueError("No Mach-O files found")
    run("codesign", "--verify", "--deep", "--strict", str(root))
    return rows


@cli.command()
def main(
    artifact: Annotated[
        Path, typer.Argument(exists=True, help="Dynamic .xcframework, signed .app, or ZIP containing one xcframework.")
    ],
    max_minos: str = typer.Option("14.0", help="Reject any slice requiring a newer OS."),
    sha256: str | None = typer.Option(None, help="Required expected ZIP checksum from the owning release."),
    platform: str = typer.Option("IOS", help="Expected app platform: IOS or IOSSIMULATOR."),
) -> None:
    """Print a JSON audit on stdout; fail closed on a missing or incompatible product."""
    try:
        version(max_minos)
        if platform not in {"IOS", "IOSSIMULATOR"}:
            raise ValueError("App platform must be IOS or IOSSIMULATOR")
        root = artifact.resolve()
        with tempfile.TemporaryDirectory(prefix="ios-artifact-") as temporary:
            if root.suffix == ".zip":
                if not sha256:
                    raise ValueError("ZIP audit requires --sha256 from the owning release")
                with root.open("rb") as source:
                    actual = hashlib.file_digest(source, "sha256").hexdigest()
                if actual != sha256.lower():
                    raise ValueError(f"ZIP SHA256 mismatch: {actual}")
                if run("swift", "package", "compute-checksum", str(root), cwd=Path(temporary)).strip() != actual:
                    raise ValueError("Swift package checksum differs from SHA256")
                with zipfile.ZipFile(root) as archive:
                    for member in archive.infolist():
                        target = (Path(temporary) / member.filename).resolve()
                        if (
                            not target.is_relative_to(Path(temporary).resolve())
                            or (member.external_attr >> 16) & 0o170000 == 0o120000
                        ):
                            raise ValueError(
                                "ZIP contains an escaping path or symlink; use an inspected extracted artifact"
                            )
                    archive.extractall(temporary)
                products = [
                    product
                    for product in Path(temporary).rglob("*.xcframework")
                    if "__MACOSX" not in product.relative_to(temporary).parts
                ]
                if len(products) != 1:
                    raise ValueError("ZIP must contain exactly one xcframework")
                root = products[0]
            if root.suffix == ".xcframework":
                rows = audit_framework(root, max_minos)
            elif root.suffix == ".app":
                rows = audit_app(root, max_minos, platform)
            else:
                raise ValueError("Expected .xcframework, .app or .zip")
            print(json.dumps({"artifact": str(artifact), "result": "PASS", "binaries": rows}, indent=2))
            console.print(f"PASS: {len(rows)} binaries, {sum(len(row['slices']) for row in rows)} architecture slices")
    except BrokenPipeError:
        raise typer.Exit(0) from None
    except KeyboardInterrupt:
        raise typer.Exit(130) from None
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        console.print(f"[red]Error:[/] {escape(str(error))}")
        raise typer.Exit(1) from None


if __name__ == "__main__":
    cli()
