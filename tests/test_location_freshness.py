"""Run the shipped location/background commands with only platform APIs replaced."""

import json
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def commands(tmp_path_factory):
    directory = tmp_path_factory.mktemp("location-cli")
    source = (ROOT / "a-Shell/AppDelegate.swift").read_text()
    # Compile the actual command implementation, without rewriting or exporting privates.
    # UIKit/SwiftUI app startup is outside this command seam; only platform fixtures replace it.
    implementation = source[
        source.index("private enum LocationRequestError:") : source.index(
            "private struct BackgroundSettings:"
        )
    ]
    implementation += source[source.index('@_cdecl("ashell_background")') :]
    fixture = ROOT / "tests/location-platform.swift"
    main = ROOT / "tests/location-command-main.swift"
    swift = directory / "commands.swift"
    swift.write_text(fixture.read_text() + implementation + main.read_text())
    binary = directory / "commands"
    subprocess.run(
        ["swiftc", "-swift-version", "5", str(swift), "-o", str(binary)],
        check=True,
        capture_output=True,
    )
    return binary


@pytest.mark.parametrize("scenario", ["reduced-cache", "reduced-delivery"])
def test_reduced_location_accepts_ten_minute_fix_and_reports_its_age(
    commands, scenario
):
    result = subprocess.run(
        [str(commands), scenario],
        capture_output=True,
        text=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    fix = json.loads(result.stdout.splitlines()[0])
    assert 599000 <= fix["elapsedMs"] <= 602000
    assert "600 s old" in result.stdout


def test_precise_location_rejects_stationary_cache_and_waits_for_fresh_delivery(
    commands,
):
    result = subprocess.run(
        [str(commands), "precise-stale"],
        capture_output=True,
        text=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout.splitlines()[0])["elapsedMs"] < 2000


def test_precise_location_times_out_when_only_stale_cache_exists(commands):
    result = subprocess.run(
        [str(commands), "precise-no-fix"],
        capture_output=True,
        text=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 124
    assert "timed out" in result.stderr


def test_reduced_location_rejects_a_fix_older_than_twenty_minutes(commands):
    result = subprocess.run(
        [str(commands), "reduced-too-old"],
        capture_output=True,
        text=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 124
    assert "timed out" in result.stderr
