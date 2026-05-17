#!/bin/bash
# Windows notification sender with deduplication
# Usage: notify.sh <event_type> <json_input>
#
# Sends a single Windows toast notification per event.
# Deduplication via mkdir lock prevents duplicate toasts when
# multiple hooks fire for the same Claude Code event.

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
            sleep 0.3  # Let Claude Code flush the transcript
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

        # Detect if Claude is waiting for input (response ends with ?)
        # or if the stop was just a pause between turns
        STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
        if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
            exit 0
        fi

        # Smart title: if response ends with ? or contains "which", "want", "should", "prefer"
        # it's likely waiting for input, not a completed task
        if echo "$RESPONSE" | grep -qiE '\?\s*$|which (one|approach|option)|do you want|should I|would you (like|prefer)'; then
            NOTIF_TITLE="⏳ Input Needed"
        else
            NOTIF_TITLE="✅ Task Completed"
        fi

        if [ -n "$RESPONSE" ]; then
            NOTIF_BODY="${RESPONSE:0:200}"
        elif [ -n "$QUERY" ]; then
            NOTIF_BODY="Done: ${QUERY:0:200}"
        else
            NOTIF_BODY="Claude finished the task"
        fi
        ;;
    idle_prompt)
        NOTIF_TITLE="⏳ Input Needed"
        MSG=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
        NOTIF_BODY="${MSG:-Claude is waiting for your input}"
        ;;
    permission_request)
        NOTIF_TITLE="🔐 Permission Required"
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "a tool"' 2>/dev/null)
        TOOL_INPUT=$(echo "$INPUT" | jq -r '(.tool_input.command // .tool_input.file_path // empty)' 2>/dev/null)
        if [ -n "$TOOL_INPUT" ]; then
            NOTIF_BODY="$TOOL_NAME: ${TOOL_INPUT:0:150}"
        else
            NOTIF_BODY="Claude wants to run: $TOOL_NAME"
        fi
        ;;
    session_start)
        rmdir "$LOCK_DIR" 2>/dev/null || true
        exit 0
        ;;
    *)
        NOTIF_TITLE="Claude Code"
        NOTIF_BODY="Needs your attention"
        ;;
esac

# === Add project context ===
if [ -n "$PROJECT" ]; then
    NOTIF_TITLE="$NOTIF_TITLE — $PROJECT"
fi

# === Send notification ===
powershell -ExecutionPolicy Bypass -NoProfile -File "$SCRIPT_DIR/win-toast.ps1" \
    -Title "$NOTIF_TITLE" -Body "$NOTIF_BODY" &>/dev/null &
