#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.13"
# dependencies = ["numpy==2.2.6", "typer==0.16.0", "rich==14.0.0"]
# ///
"""Qualify installed embedding packages through the public CLI, never private inference."""

import hashlib
import json
import os
import subprocess
from pathlib import Path

import numpy as np
import typer
from rich.console import Console

app = typer.Typer(pretty_exceptions_enable=False)
console = Console(stderr=True)


@app.command()
def main(
    runtime: Path,
    model_id: str,
    reference: Path,
    output: Path,
    precision: str = "float32",
):
    output.mkdir(parents=True, exist_ok=False)
    frozen = json.loads(reference.read_bytes())
    corpus_path = Path(__file__).resolve().parents[1] / "models/embedding-corpus.json"
    corpus_bytes = corpus_path.read_bytes()
    corpus = json.loads(corpus_bytes)
    assert hashlib.sha256(corpus_bytes).hexdigest() == frozen["corpus_sha256"]
    rows = []

    def run(request, name, status=0):
        path = output / f"{name}.input.json"
        path.write_text(json.dumps(request, ensure_ascii=False))
        argv = [str(runtime.resolve()), "embed", model_id, str(path), "--units", "cpu"]
        p = subprocess.run(
            argv, capture_output=True, timeout=600, env=os.environ, check=False
        )
        (output / f"{name}.stdout").write_bytes(p.stdout)
        (output / f"{name}.stderr").write_bytes(p.stderr)
        rows.append(
            {
                "argv": argv,
                "exit": p.returncode,
                "stdout_sha256": hashlib.sha256(p.stdout).hexdigest(),
            }
        )
        assert p.returncode == status, (name, p.returncode, p.stderr.decode())
        if status:
            assert not p.stdout and p.stderr
            return None
        return json.loads(p.stdout)

    results = []
    for index, entry in enumerate(frozen["cases"]):
        result = run(entry["request"], f"case-{index}")
        vectors = np.asarray(result["embeddings"])
        expected = np.asarray(entry["expected"])
        assert vectors.shape == expected.shape and np.isfinite(vectors).all()
        assert (
            result["normalized"]
            and np.max(np.abs(np.linalg.norm(vectors, axis=1) - 1)) < 1e-5
        )
        cosine = (vectors * expected).sum(axis=1) / np.linalg.norm(expected, axis=1)
        assert cosine.min() >= corpus["thresholds"][precision], (index, cosine.min())
        assert (
            result["token_counts"] == entry["token_counts"]
            and result["truncated"] == entry["truncated"]
        )
        results.append(
            {"minimum_cosine": float(cosine.min()), "memory": result["memory"]}
        )
    docs = np.asarray(run({"texts": corpus["documents"]}, "documents")["embeddings"])
    query = {"texts": corpus["queries"]}
    if model_id.startswith("qwen"):
        query["instruction"] = corpus["instruction"]
    queries = np.asarray(run(query, "queries")["embeddings"])
    scores = np.einsum("id,jd->ij", queries, docs)
    assert np.isfinite(scores).all()
    actual = np.argsort(-scores, axis=1, kind="stable")[:, : corpus["k"]]
    expected = frozen["retrieval_top_k"]
    overlap = [
        len(set(a.tolist()) & set(b)) / corpus["k"]
        for a, b in zip(actual, expected, strict=True)
    ]
    assert min(overlap) >= corpus["thresholds"]["top_k_overlap"], overlap
    for index, bad in enumerate(
        [
            {},
            {"texts": []},
            {"texts": [""]},
            {"texts": [1]},
            {"texts": ["hello " * 150]},
            {"texts": ["ok"], "truncate": "yes"},
            {"texts": ["ok"], "unknown": 1},
        ]
    ):
        run(bad, f"bad-{index}", 2)
    run({"texts": ["Recovery after invalid input"]}, "recovery")
    receipt = {
        "result": "EMBEDDING_CLI_PASS",
        "model_id": model_id,
        "precision": precision,
        "cases": results,
        "top_k_overlap": overlap,
        "commands": rows,
        "runtime_sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
        "reference_sha256": hashlib.sha256(reference.read_bytes()).hexdigest(),
        "corpus_sha256": frozen["corpus_sha256"],
    }
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))


if __name__ == "__main__":
    app()
