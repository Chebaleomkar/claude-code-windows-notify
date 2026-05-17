#!/bin/bash
# Hook: Stop — notify when Claude Code completes a task

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)

# Skip if a stop hook is already active
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

"$SCRIPT_DIR/notify.sh" "stop" "$INPUT"
