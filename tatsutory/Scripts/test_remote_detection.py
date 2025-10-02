#!/usr/bin/env python3
"""Minimal standalone tester for the remote detection API.

Usage:
    python scripts/test_remote_detection.py --image path/to/photo.jpg

The script reads `OPENAI_API_KEY` either from the environment or from a local
`.env` file (key=value format). It performs a single POST request to the
OpenAI Responses API and prints status, headers, and body so we can inspect
rate-limit behaviour outside the app.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path
from typing import Dict

import requests

API_ENDPOINT = "https://api.openai.com/v1/responses"
MODEL_ID = "gpt-5-mini"


def load_env_file(path: Path) -> None:
    """Simple .env loader (key=value, ignores comments)."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def encode_image(image_path: Path) -> str:
    with image_path.open("rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def build_payload(image_b64: str) -> Dict:
    return {
        "model": MODEL_ID,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "remote_detection",
                "schema": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "items": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "additionalProperties": False,
                                "properties": {
                                    "id": {"type": "string"},
                                    "label": {"type": "string"},
                                    "bbox": {
                                        "type": "array",
                                        "items": {"type": "number"},
                                        "minItems": 4,
                                        "maxItems": 4
                                    },
                                    "confidence": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1
                                    }
                                },
                                "required": ["id", "label", "bbox", "confidence"]
                            }
                        }
                    },
                    "required": ["items"]
                }
            }
        },
        "input": [
            {
                "role": "system",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "You are an object detector for household disposal planning. "
                            "Respond with valid JSON matching {\"items\":[{\"id\":\"str\",\"label\":\"str\",\"bbox\":[x,y,w,h],\"confidence\":0..1}]}. "
                            "Coordinates must be normalized 0-1. Reply with JSON only."
                        ),
                    }
                ],
            },
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": "Detect major household items (furniture/appliances)."},
                    {"type": "input_image", "image_url": f"data:image/jpeg;base64,{image_b64}"},
                ],
            },
        ],
        "max_output_tokens": 1200,
        "reasoning": {"effort": "low"},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Test remote detection API with a single image.")
    parser.add_argument("--image", required=True, help="Path to JPEG image to send")
    args = parser.parse_args()

    load_env_file(Path(".env"))

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("[error] OPENAI_API_KEY is not set. Export it or put it in .env", file=sys.stderr)
        return 1

    image_path = Path(args.image)
    if not image_path.exists():
        print(f"[error] image not found: {image_path}", file=sys.stderr)
        return 1

    image_b64 = encode_image(image_path)
    payload = build_payload(image_b64)

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    print(time.strftime("%Y-%m-%d %H:%M:%S"), "sending request...", flush=True)
    response = requests.post(API_ENDPOINT, headers=headers, data=json.dumps(payload))

    print("Status:", response.status_code)
    print("Headers:")
    for key, value in response.headers.items():
        print(f"  {key}: {value}")

    print("Body:")
    try:
        print(json.dumps(response.json(), indent=2))
    except json.JSONDecodeError:
        print(response.text)

    return 0 if response.ok else 1


if __name__ == "__main__":
    sys.exit(main())
