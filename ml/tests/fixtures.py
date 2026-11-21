#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["typer", "rich"]
# ///
"""Write tiny, untrained tokenizer contracts for the public C API."""

import json
from pathlib import Path

import typer


def generate(output: Path):
    output.mkdir(parents=True, exist_ok=False)
    models = {}
    for name, kind, vocab, ids in (
        ("minilm-l6", "WordPiece", {"hello": 3, "world": 4}, [101, 3, 4, 102]),
        ("qwen3-embedding-0.6b", "BPE", {"h": 3, "i": 4}, [3, 4, 151643]),
    ):
        qwen = kind == "BPE"
        tokenizer = {"model": {"type": kind, "vocab": vocab, "merges": []}, "added_tokens": []}
        if qwen:
            tokenizer["pre_tokenizer"] = {"pretokenizers": [{"pattern": {"Regex": ".+"}}]}
        padding = 128 - len(ids)
        case = {
            "request": {"texts": ["hi" if qwen else "Hello world"]},
            "ids": [[151643] * padding + ids if qwen else ids + [0] * padding],
            "mask": [[0] * padding + [1] * len(ids) if qwen else [1] * len(ids) + [0] * padding],
        }
        models[name] = {"cases": [case]}
        (output / f"{name}-tokenizer.json").write_text(json.dumps(tokenizer) + "\n")
    (output / "tokenizers.json").write_text(json.dumps({"models": models}) + "\n")


if __name__ == "__main__":
    typer.run(generate)
