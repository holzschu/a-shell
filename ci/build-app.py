#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer==0.21.1", "rich==14.3.3"]
# ///
"""Stage checksum-pinned framework inputs and build an unsigned a-Shell app."""

import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "a-Shell.xcodeproj"
SCHEMES = ("a-Shell-noPython", "a-Shell-mini", "a-Shell")
DESTINATIONS = {
    "device": ("iOS", "iphoneos", {"arm64"}),
    "simulator": ("iOS Simulator", "iphonesimulator", {"arm64", "x86_64"}),
}
cli = typer.Typer(no_args_is_help=True, pretty_exceptions_enable=False)
console = Console(stderr=True, markup=False, highlight=False)


def app_archs(scheme, platform):
    if (scheme, platform) == ("a-Shell", "simulator"):
        return {"arm64"}
    return DESTINATIONS[platform][2]


class InputError(Exception):
    pass


class IncompatibleSlice(InputError):
    pass


def required_paths(root, scheme):
    project = subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", root / PROJECT / "project.pbxproj"]
    )
    objects = json.loads(project)["objects"]
    parents = {
        child: key
        for key, obj in objects.items()
        if obj["isa"] == "PBXGroup"
        for child in obj["children"]
    }

    def resolve(key):
        obj = objects[key]
        path = Path(obj.get("path", ""))
        if obj.get("sourceTree") == "SOURCE_ROOT":
            return path
        if obj.get("sourceTree") != "<group>":
            return None  # SDK or built product, not an external input.
        parent = resolve(parents[key]) if key in parents else Path()
        return parent / path if parent is not None else None

    remaining = [
        key
        for key, obj in objects.items()
        if obj["isa"] == "PBXNativeTarget" and obj["name"] == scheme
    ]
    if len(remaining) != 1:
        raise InputError(f"expected one Xcode target named {scheme}")
    paths, seen = set(), set()
    while remaining:
        key = remaining.pop()
        if key in seen:
            continue
        seen.add(key)
        obj = objects[key]
        for phase in obj["buildPhases"]:
            for build_file in objects[phase].get("files", []):
                ref = objects[build_file].get("fileRef")
                if (
                    ref
                    and (path := resolve(ref)) is not None
                    and path.suffix in {".a", ".dylib", ".framework", ".xcframework"}
                ):
                    paths.add(path)
        for dependency in obj["dependencies"]:
            if target := objects[dependency].get("target"):
                remaining.append(target)
    return paths


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def fetch(cache, source):
    sha = source["sha256"]
    url = source["url"]
    if not re.fullmatch(r"[a-f0-9]{64}", sha) or not url.startswith("https://"):
        raise InputError("expected an HTTPS URL and SHA-256 pin")
    archive = cache / f"{sha}.zip"
    if not archive.exists():
        with tempfile.TemporaryDirectory(dir=cache) as temporary:
            incoming = Path(temporary) / "download.zip"
            response = subprocess.run(
                [
                    "curl",
                    "--proto",
                    "=https",
                    "--proto-redir",
                    "=https",
                    "--location",
                    "--silent",
                    "--fail",
                    "--retry",
                    "2",
                    "--connect-timeout",
                    "15",
                    "--max-time",
                    "300",
                    "--write-out",
                    "%{http_code}",
                    "--output",
                    incoming,
                    url,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            if response.returncode:
                raise InputError(
                    f"download failed (curl exit {response.returncode}, HTTP {response.stdout})"
                )
            if digest(incoming) != sha:
                raise InputError("download SHA-256 mismatch")
            incoming.replace(archive)
    elif digest(archive) != sha:
        raise InputError(f"cached SHA-256 mismatch: {archive}")
    return archive


def verify_archs(binary, archs):
    result = subprocess.run(
        ["xcrun", "lipo", "-archs", binary], capture_output=True, text=True, check=False
    )
    actual = set(result.stdout.split()) if result.returncode == 0 else set()
    if not archs <= actual:
        got = ", ".join(sorted(actual)) or "no readable Mach-O"
        need = ", ".join(sorted(archs))
        raise IncompatibleSlice(f"requires {need}; found {got}")


def select_library(framework, platform, archs):
    with (framework / "Info.plist").open("rb") as stream:
        libraries = plistlib.load(stream)["AvailableLibraries"]
    variant = "simulator" if platform == "simulator" else None
    candidates = [
        lib
        for lib in libraries
        if lib["SupportedPlatform"] == "ios"
        and lib.get("SupportedPlatformVariant") == variant
    ]
    for lib in candidates:
        if archs <= set(lib["SupportedArchitectures"]):
            library = framework / lib["LibraryIdentifier"] / lib["LibraryPath"]
            if library.suffix == ".framework":
                with (library / "Info.plist").open("rb") as stream:
                    binary = library / plistlib.load(stream)["CFBundleExecutable"]
            else:
                binary = library
            verify_archs(binary, archs)
            return library
    got = (
        "; ".join(", ".join(lib["SupportedArchitectures"]) for lib in candidates)
        or "none"
    )
    raise IncompatibleSlice(
        f"no {platform} slice with {', '.join(sorted(archs))} (found {got})"
    )


def copy_member(bundle_path, member, output_path):
    with (
        zipfile.ZipFile(bundle_path) as bundle,
        bundle.open(member) as stream,
        output_path.open("wb") as output,
    ):
        shutil.copyfileobj(stream, output)


def unpack_zip(archive, folder):
    result = subprocess.run(
        ["ditto", "-x", "-k", archive, folder], capture_output=True, check=False
    )
    if result.returncode:
        raise InputError("could not extract ZIP")


def python_a_source(path):
    if path.suffix != ".framework":
        return None
    if path.stem == "pythonA":
        return "Python"
    if path.stem.startswith("PythonA") and len(path.stem) > len("PythonA"):
        return "Python-" + path.stem.removeprefix("PythonA")
    return None


def rename_python_framework(bundle, name):
    # Keep the second interpreter's identities the same as updatePythonFiles.sh.
    info = bundle / "Info.plist"
    plist = plistlib.loads(info.read_bytes())
    original = plist["CFBundleExecutable"]
    bundle = bundle.rename(bundle.with_name(f"{name}.framework"))
    binary = (bundle / original).rename(bundle / name)
    origin = bundle / f"{original}.origin"
    if origin.is_file():
        origin.rename(bundle / f"{name}.origin")
    plist.update(
        CFBundleExecutable=name,
        CFBundleIdentifier="Nicolas-Holzschuch." + name.replace("_", "-"),
        CFBundleName=name,
    )
    (bundle / "Info.plist").write_bytes(plistlib.dumps(plist))
    rewrite = ["xcrun", "install_name_tool", "-id", f"@rpath/{name}.framework/{name}"]
    if name != "pythonA":
        rewrite += [
            "-change",
            "@rpath/Python.framework/Python",
            "@rpath/pythonA.framework/pythonA",
        ]
    subprocess.run([*rewrite, binary], check=True)
    subprocess.run(["codesign", "--force", "--sign", "-", bundle], check=True)
    return bundle


def unpack_framework(archive, member, folder, path, platform, name, archs):
    folder.mkdir()
    if member:
        inner = folder / "framework.zip"
        copy_member(archive, member, inner)
        archive = inner
    unpack_zip(archive, folder)
    framework = folder / f"{name}.xcframework"
    if not framework.is_dir():
        raise InputError(f"ZIP does not contain {framework.name}")
    library = select_library(framework, platform, archs)
    if path.suffix == ".xcframework":
        return framework
    if library.suffix != path.suffix:
        raise InputError(f"expected a {path.suffix} product, found {library.name}")
    if name != path.stem:
        return rename_python_framework(library, path.stem)
    return library


def checkout_path(root, path):
    destination = root / path
    if path.is_absolute() or not destination.resolve().is_relative_to(root):
        raise InputError(f"input path is outside the worktree: {path}")
    return destination


def install(root, path, product, owned):
    destination = checkout_path(root, path)
    if destination.exists() or destination.is_symlink():
        if str(path) not in owned:
            raise InputError(
                f"destination already exists: {path}; use a clean worktree"
            )
        if destination.is_dir() and not destination.is_symlink():
            shutil.rmtree(destination)
        else:
            destination.unlink()
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(product, destination)
    owned.add(str(path))


def stage_resources(root, plan, artifacts, get_archive, directory, platform, owned):
    _, sdk, _ = DESTINATIONS[platform]
    for group_index, (destination, layers) in enumerate(plan.items()):
        group = directory / f"resources-{group_index}"
        result = group / "resource"
        result.mkdir(parents=True)
        for index, layer in enumerate(layers):
            member = layer["member"]
            archive = group / Path(member).name
            payload = group / str(index)
            payload.mkdir()
            copy_member(get_archive(artifacts[layer["artifact"]]), member, archive)
            if member.endswith(".tar.gz"):
                shutil.unpack_archive(archive, payload, filter="data")
            elif member.endswith(".zip"):
                unpack_zip(archive, payload)
            else:
                raise InputError(f"unsupported resource archive: {member}")
            subtree = payload / layer.get("source", "").replace("{sdk}", sdk)
            if not subtree.is_dir() or not subtree.resolve().is_relative_to(payload):
                raise InputError(f"resource directory missing from {member}: {subtree}")
            shutil.copytree(subtree, result, dirs_exist_ok=True, symlinks=True)
        install(root, Path(destination), result, owned)


def report(scheme, platform, result):
    body = f"### {scheme} / {platform}\n\n{result}\n"
    console.print(body)
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(summary).open("a") as stream:
            stream.write(body)


def stage(root, manifest, scheme, platform, dry_run):
    data = json.loads(manifest.read_text())
    paths = required_paths(root, scheme) | {
        Path(path) for path in data.get("extra", {}).get(scheme, {}).get(platform, [])
    }
    artifacts = {
        name: (artifact, member)
        for artifact in data["artifacts"].values()
        for name, member in artifact["frameworks"].items()
    }
    missing, options = {}, {}
    for path in sorted(paths):
        checkout_path(root, path)
        name = path.stem
        if name not in data["releases"] and name not in artifacts:
            name = python_a_source(path) or name
        release = data["releases"].get(name)
        choices = [(release, None)] if release else []
        if name in artifacts:
            choices.append(artifacts[name])
        if choices:
            options[path] = (name, choices)
        else:
            recipe = data["pending"].get(path.stem) or next(
                (
                    recipe
                    for prefix, recipe in data.get("pending_prefixes", {}).items()
                    if path.stem.startswith(prefix)
                ),
                None,
            )
            missing[path] = (
                f"no pinned artifact ({recipe})" if recipe else "no manifest entry"
            )
    if dry_run:
        for path in options:
            print(path)
        return missing, paths

    working = root / ".build/app-frameworks"
    cache = working / "archives"
    cache.mkdir(parents=True, exist_ok=True)
    owned_file = working / "installed.json"
    owned = set(json.loads(owned_file.read_text())) if owned_file.exists() else set()
    with (
        tempfile.TemporaryDirectory(dir=working) as directory,
        ThreadPoolExecutor(4) as pool,
    ):
        downloads = {
            choices[0][0]["sha256"]: choices[0][0] for _, choices in options.values()
        }
        futures = {
            sha: pool.submit(fetch, cache, source) for sha, source in downloads.items()
        }

        def get_archive(source):
            sha = source["sha256"]
            if sha not in futures:
                futures[sha] = pool.submit(fetch, cache, source)
            return futures[sha].result()

        for index, (path, (name, choices)) in enumerate(options.items()):
            archs = (
                app_archs(scheme, platform)
                if path == Path("xcfs/node.xcframework")
                else DESTINATIONS[platform][2]
            )
            for attempt, (source, member) in enumerate(choices):
                try:
                    product = unpack_framework(
                        get_archive(source),
                        member,
                        Path(directory) / f"{index}-{attempt}",
                        path,
                        platform,
                        name,
                        archs,
                    )
                    install(root, path, product, owned)
                    break
                except IncompatibleSlice as error:
                    if attempt == len(choices) - 1:
                        missing[path] = str(error)
                except (
                    InputError,
                    OSError,
                    zipfile.BadZipFile,
                    KeyError,
                    plistlib.InvalidFileException,
                    subprocess.CalledProcessError,
                ) as error:
                    missing[path] = str(error)
                    break
        try:
            if not missing:
                stage_resources(
                    root,
                    data.get("resources", {}).get(scheme, {}),
                    data["artifacts"],
                    get_archive,
                    Path(directory),
                    platform,
                    owned,
                )
        finally:
            temporary = owned_file.with_suffix(".tmp")
            temporary.write_text(json.dumps(sorted(owned)) + "\n")
            temporary.replace(owned_file)
    return missing, paths


def prepare_inputs(root, manifest, scheme, platform, dry_run=False):
    if scheme not in SCHEMES or platform not in DESTINATIONS:
        raise typer.BadParameter("expected an app scheme and device or simulator")
    manifest = manifest or root / "xcfs/frameworks.json"
    try:
        missing, paths = stage(root, manifest, scheme, platform, dry_run)
    except (
        InputError,
        OSError,
        ValueError,
        KeyError,
        zipfile.BadZipFile,
        shutil.ReadError,
        subprocess.CalledProcessError,
    ) as error:
        report(scheme, platform, f"Input preparation failed: {error}")
        raise typer.Exit(1) from error
    count = len(paths)
    if missing:
        lines = [
            f"{len(missing)} of {count} required framework inputs unavailable:",
            "",
        ]
        lines.extend(
            f"- `{path}`: {reason}" for path, reason in sorted(missing.items())
        )
        report(scheme, platform, "\n".join(lines))
        raise typer.Exit(1)
    if not dry_run:
        report(scheme, platform, f"Verified all {count} required framework inputs.")
    return paths


@cli.command()
def prepare(
    scheme: str,
    platform: str,
    root: Annotated[Path, typer.Option(resolve_path=True)] = ROOT,
    manifest: Path | None = None,
    dry_run: bool = False,
):
    """Materialize and verify inputs without compiling the app."""
    prepare_inputs(root, manifest, scheme, platform, dry_run)


@cli.command()
def build(
    scheme: str,
    platform: str,
    root: Annotated[Path, typer.Option(resolve_path=True)] = ROOT,
    manifest: Path | None = None,
    dry_run: bool = False,
):
    """Verify inputs, build the app and check its executable architectures."""
    paths = prepare_inputs(root, manifest, scheme, platform, dry_run)
    if dry_run:
        return
    runtimes = [path for path in paths if path.name == "ios_system.xcframework"]
    if len(runtimes) != 1:
        report(scheme, platform, "Expected exactly one staged ios_system.xcframework.")
        raise typer.Exit(1)
    try:
        result = subprocess.run(
            [
                "bash",
                Path(__file__).with_name("check-ios-system.sh"),
                root,
                root / runtimes[0],
                platform,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        detail = (
            error.stdout
            if isinstance(error, subprocess.CalledProcessError)
            else str(error)
        )
        report(
            scheme,
            platform,
            f"Pinned ios_system ABI check failed:\n\n```text\n{detail}\n```",
        )
        raise typer.Exit(1) from error
    report(scheme, platform, result.stdout.strip())
    destination, sdk, _ = DESTINATIONS[platform]
    archs = app_archs(scheme, platform)
    derived = root / ".build/app" / f"{scheme}-{platform}"
    try:
        derived.mkdir(parents=True, exist_ok=True)
        settings = derived / "app-architectures.xcconfig"
        # A global ARCHS=arm64 builds SwiftTerm's macOS tool for the wrong CPU on Intel.
        settings.write_text(
            f"ARCHS[sdk={sdk}*] = {' '.join(sorted(archs))}\n"
            f"ONLY_ACTIVE_ARCH[sdk={sdk}*] = NO\n"
        )
        subprocess.run(
            ["git", "submodule", "update", "--init", "--", "SwiftTerm"],
            cwd=root,
            check=True,
        )
        subprocess.run(
            [
                "nice",
                "-n",
                "15",
                "xcodebuild",
                "-project",
                PROJECT,
                "-scheme",
                scheme,
                "-configuration",
                "Debug",
                "-destination",
                f"generic/platform={destination}",
                "-derivedDataPath",
                derived,
                "-jobs",
                "4",
                "-xcconfig",
                settings,
                "CODE_SIGNING_ALLOWED=NO",
                "build",
            ],
            cwd=root,
            check=True,
        )
        verify_archs(
            derived / "Build/Products" / f"Debug-{sdk}" / f"{scheme}.app" / scheme,
            archs,
        )
    except (InputError, OSError, subprocess.CalledProcessError) as error:
        report(scheme, platform, f"Build or executable verification failed: {error}")
        raise typer.Exit(1) from error
    report(scheme, platform, f"Unsigned app built with {', '.join(sorted(archs))}.")


@cli.command()
def package(
    root: Annotated[Path, typer.Option(resolve_path=True)] = ROOT,
    check: bool = False,
):
    """Print the release-only SwiftPM manifest, or check the committed copy."""
    releases = json.loads((root / "xcfs/frameworks.json").read_text())["releases"]
    targets = [
        f'        .binaryTarget(name: "{name}", url: "{source["url"]}", '
        f'checksum: "{source["sha256"]}"),'
        for name, source in releases.items()
    ]
    swift = (
        "// swift-tools-version:5.3\n"
        "// Generated by `uv run ci/build-app.py package` from xcfs/frameworks.json.\n"
        "import PackageDescription\n\n"
        "let package = Package(\n"
        '    name: "xcfs",\n'
        '    platforms: [.macOS("11")],\n'
        '    dependencies: [.package(url: "https://github.com/holzschu/FMake", from: "0.0.19")],\n'
        "    targets: [\n"
        + "\n".join(targets)
        + '\n        .target(name: "build", dependencies: ["FMake"]),\n'
        "    ]\n"
        ")\n"
    )
    if not check:
        print(swift, end="")
    elif (root / "xcfs/Package.swift").read_text() != swift:
        console.print("xcfs/Package.swift is out of sync with xcfs/frameworks.json")
        raise typer.Exit(1)


if __name__ == "__main__":
    cli()
