#!/usr/bin/env python3
"""
Generate test fixtures for anthropic-sdk-haskell using grievous-mcp.
https://pypi.org/project/grievous-mcp/

Install:
    pip install grievous-mcp

Run from the repo root (ANTHROPIC_API_KEY must be set):
    python test/fixtures/generate.py

Fixtures are saved as JSON files alongside this script.
Regenerate whenever the Anthropic API schema changes.
Generated: 2026-04-27
"""

import json
import os

from grievous.backend import generate

FIXTURES = {
    "message_text": (
        "an Anthropic API Message response object with fields: "
        "id (string like 'msg_01AbCdEfGhIjKlMnOpQrStUv'), "
        "type='message', role='assistant', "
        "content (array with exactly one object: {type:'text', text:'Hello! How can I help you today?'}), "
        "model='claude-3-5-sonnet-20241022', "
        "stop_reason='end_turn', stop_sequence=null, "
        "usage={input_tokens:25, output_tokens:13, "
        "cache_creation_input_tokens:null, cache_read_input_tokens:null}"
    ),
    "message_tool_use": (
        "an Anthropic API Message response object with fields: "
        "id (string like 'msg_01AbCdEfGhIjKlMnOpQrStUv'), "
        "type='message', role='assistant', "
        "content (array with exactly one object: "
        "{type:'tool_use', id:'toolu_01AbCdEfGh', name:'get_weather', "
        "input:{location:'San Francisco', unit:'celsius'}}), "
        "model='claude-3-5-sonnet-20241022', "
        "stop_reason='tool_use', stop_sequence=null, "
        "usage={input_tokens:82, output_tokens:23, "
        "cache_creation_input_tokens:null, cache_read_input_tokens:null}"
    ),
    "message_max_tokens": (
        "an Anthropic API Message response object with fields: "
        "id (string like 'msg_01AbCdEfGhIjKlMnOpQrStUv'), "
        "type='message', role='assistant', "
        "content (array with exactly one object: {type:'text', text:'The story begins with'}), "
        "model='claude-3-5-sonnet-20241022', "
        "stop_reason='max_tokens', stop_sequence=null, "
        "usage={input_tokens:15, output_tokens:5, "
        "cache_creation_input_tokens:null, cache_read_input_tokens:null}"
    ),
    "error_rate_limit": (
        "an Anthropic API error response envelope with fields: "
        "type='error', "
        "error={type:'rate_limit_error', message:'Rate limit exceeded. Please retry after 60 seconds.'}"
    ),
    "error_invalid_request": (
        "an Anthropic API error response envelope with fields: "
        "type='error', "
        "error={type:'invalid_request_error', message:'max_tokens must be a positive integer'}"
    ),
    "error_auth": (
        "an Anthropic API error response envelope with fields: "
        "type='error', "
        "error={type:'authentication_error', message:'Invalid API key provided.'}"
    ),
}


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    for name, schema in FIXTURES.items():
        print(f"Generating {name}...", end=" ", flush=True)
        data = generate(schema)
        path = os.path.join(out_dir, f"{name}.json")
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        print("done")
    print(f"\nFixtures written to {out_dir}/")


if __name__ == "__main__":
    main()
