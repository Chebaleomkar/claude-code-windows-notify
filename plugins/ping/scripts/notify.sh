#!/bin/bash
# Ping — Windows notification sender with deduplication
# Usage: notify.sh <event_type> <json_input>

# Only run on Windows
[ -z "$WINDIR" ] && exit 0
command -v powershell &>/dev/null || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EVENT_TYPE="${1:-unknown}"
INPUT="${2:-{}}"

# === Deduplication (8-second window, per event type) ===
LOCK_DIR="/tmp/claude-win-notify-lock-${EVENT_TYPE}"
if mkdir "$LOCK_DIR" 2>/dev/null; then
    (sleep 8 && rmdir "$LOCK_DIR" 2>/dev/null) &
else
    exit 0
fi

# === Extract context ===
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
PROJECT=""
if [ -n "$CWD" ]; then
    PROJECT=$(basename "$CWD")
fi

# === Build notification based on event type ===
case "$EVENT_TYPE" in
    stop)
        TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
        RESPONSE=""
        QUERY=""
        if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
            sleep 0.3
            RESPONSE=$(jq -rs '
                [.[] | select(.type == "assistant" and .message.content)] | last |
                [.message.content[] | select(.type == "text") | .text] | join(" ")
            ' "$TRANSCRIPT_PATH" 2>/dev/null)
            QUERY=$(jq -rs '
                [
                    .[] | select(.type == "user") |
                    if .message.content | type == "string" then .
                    elif [.message.content[] | select(.type == "text")] | length > 0 then .
                    else empty end
                ] | last |
                if .message.content | type == "array"
                then [.message.content[] | select(.type == "text") | .text] | join(" ")
                else .message.content // empty end
            ' "$TRANSCRIPT_PATH" 2>/dev/null)
        fi

        STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
        if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
            exit 0
        fi

        # Smart detection: input needed vs task completed
        if echo "$RESPONSE" | grep -qiE '\?\s*$|which (one|approach|option)|do you want|should I|would you (like|prefer)'; then
            NOTIF_TITLE="Awaiting Response"
        else
            NOTIF_TITLE="Task Completed"
        fi

        if [ -n "$RESPONSE" ]; then
            # Clean the response: strip markdown, trim whitespace
            CLEAN=$(echo "$RESPONSE" | sed 's/[#*`_~]//g' | sed 's/^[[:space:]]*//' | head -c 180)
            NOTIF_BODY="$CLEAN"
        elif [ -n "$QUERY" ]; then
            NOTIF_BODY="Completed: ${QUERY:0:150}"
        else
            NOTIF_BODY="Claude has finished processing."
        fi
        ;;
    idle_prompt)
        NOTIF_TITLE="Awaiting Response"
        MSG=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
        NOTIF_BODY="${MSG:-Claude is waiting for your response.}"
        ;;
    permission_request)
        NOTIF_TITLE="Action Required"
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "a tool"' 2>/dev/null)
        TOOL_INPUT=$(echo "$INPUT" | jq -r '(.tool_input.command // .tool_input.file_path // empty)' 2>/dev/null)
        if [ -n "$TOOL_INPUT" ]; then
            NOTIF_BODY="Approve $TOOL_NAME — ${TOOL_INPUT:0:120}"
        else
            NOTIF_BODY="Claude needs permission to run $TOOL_NAME"
        fi
        ;;
    session_start)
        rmdir "$LOCK_DIR" 2>/dev/null || true
        exit 0
        ;;
    *)
        NOTIF_TITLE="Ping"
        NOTIF_BODY="Claude Code needs your attention."
        ;;
esac

# === Add project context ===
if [ -n "$PROJECT" ]; then
    NOTIF_TITLE="$NOTIF_TITLE · $PROJECT"
fi

# === Send notification ===
powershell -ExecutionPolicy Bypass -NoProfile -File "$SCRIPT_DIR/win-toast.ps1" \
    -Title "$NOTIF_TITLE" -Body "$NOTIF_BODY" &>/dev/null &
