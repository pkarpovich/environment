#!/bin/bash
set -e

INPUT_FILE="$1"
OUTPUT_FILE="${2:-/tmp/langfuse-trace-normalized.json}"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: normalize.sh <input.json> [output.json]"
    echo "Decodes nested JSON strings in Langfuse trace exports"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE"
    exit 1
fi

DECODE='walk(if type == "string" and (startswith("{") or startswith("[") or startswith("\"")) then (try fromjson catch .) else . end)'
jq "$DECODE | $DECODE" "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Normalized trace saved to: $OUTPUT_FILE"
