#!/bin/bash
# Hook: SessionStart — show welcome message in Claude Code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT=$(cat)

# Only activate on Windows
if [ -z "$WINDIR" ]; then
    exit 0
fi

# Show system message confirming the plugin is active
cat << 'EOF'
{"systemMessage": "🔔 Windows notifications active. You'll receive desktop toasts when tasks complete or input is needed."}
EOF
