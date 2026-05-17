#!/bin/bash
# Hook: Notification (idle_prompt) — notify when Claude is waiting for input

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(timeout 2 cat 2>/dev/null || echo '{}')

"$SCRIPT_DIR/notify.sh" "idle_prompt" "$INPUT"
