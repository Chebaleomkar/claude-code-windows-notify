#!/bin/bash
# Hook: PermissionRequest — notify when Claude needs permission to run a tool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(timeout 2 cat 2>/dev/null || echo '{}')

"$SCRIPT_DIR/notify.sh" "permission_request" "$INPUT"
