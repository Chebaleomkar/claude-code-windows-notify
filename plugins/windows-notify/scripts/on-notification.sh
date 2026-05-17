#!/bin/bash
# Hook: Notification (idle_prompt) — notify when Claude is waiting for input

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)

"$SCRIPT_DIR/notify.sh" "idle_prompt" "$INPUT"
