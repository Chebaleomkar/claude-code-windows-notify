#!/bin/bash
# Tests for claude-code-windows-notify plugin
#
# Usage: bash tests/test-notify.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"

PASSED=0
FAILED=0

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $test_name"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ $test_name"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAILED=$((FAILED + 1))
    fi
}

# Mock powershell
MOCK_DIR=$(mktemp -d)
MOCK_LOG="$MOCK_DIR/powershell-calls.log"
cat > "$MOCK_DIR/powershell" << 'EOF'
#!/bin/bash
echo "$@" >> "$(dirname "$0")/powershell-calls.log"
EOF
chmod +x "$MOCK_DIR/powershell"

cleanup() {
    rm -rf "$MOCK_DIR"
    rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Plugin Structure ==="

echo ""
echo "--- Required files exist ---"
for f in ".claude-plugin/plugin.json" "hooks/hooks.json" "scripts/notify.sh" "scripts/win-toast.ps1" "scripts/on-stop.sh" "scripts/on-notification.sh" "scripts/on-permission-request.sh" "scripts/on-session-start.sh"; do
    FULL="$(dirname "$SCRIPT_DIR")/$f"
    if [ -f "$FULL" ]; then
        echo "  ✓ $f exists"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ $f missing"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "--- plugin.json valid ---"
PLUGIN_JSON="$(dirname "$SCRIPT_DIR")/.claude-plugin/plugin.json"
NAME=$(jq -r '.name' "$PLUGIN_JSON" 2>/dev/null)
assert_eq "plugin name is windows-notify" "windows-notify" "$NAME"
VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null)
assert_eq "plugin version is 1.0.0" "1.0.0" "$VERSION"

echo ""
echo "--- hooks.json has required events ---"
HOOKS_JSON="$(dirname "$SCRIPT_DIR")/hooks/hooks.json"
for event in Stop Notification PermissionRequest SessionStart; do
    if jq -e ".hooks.$event" "$HOOKS_JSON" &>/dev/null; then
        echo "  ✓ $event hook registered"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ $event hook missing"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== notify.sh ==="

echo ""
echo "--- Exits on non-Windows ---"
unset WINDIR
bash "$SCRIPT_DIR/notify.sh" "stop" '{}' 2>/dev/null
assert_eq "exits silently on non-Windows" "0" "$?"

echo ""
echo "--- Event routing on Windows ---"
export WINDIR="C:\\Windows"
export PATH="$MOCK_DIR:$PATH"

# Stop event
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "stop" '{"cwd":"/tmp/my-project"}' 2>/dev/null
sleep 0.5
CALL=$(cat "$MOCK_LOG" 2>/dev/null)
if echo "$CALL" | grep -q "Task Completed"; then
    echo "  ✓ stop → Task Completed"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ stop → expected Task Completed"
    echo "    got: $CALL"
    FAILED=$((FAILED + 1))
fi

# Idle prompt
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "idle_prompt" '{"cwd":"/tmp/proj"}' 2>/dev/null
sleep 0.5
CALL=$(cat "$MOCK_LOG" 2>/dev/null)
if echo "$CALL" | grep -q "Input Needed"; then
    echo "  ✓ idle_prompt → Input Needed"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ idle_prompt → expected Input Needed"
    echo "    got: $CALL"
    FAILED=$((FAILED + 1))
fi

# Permission request
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "permission_request" '{"cwd":"/tmp/proj","tool_name":"Bash"}' 2>/dev/null
sleep 0.5
CALL=$(cat "$MOCK_LOG" 2>/dev/null)
if echo "$CALL" | grep -q "Permission Required"; then
    echo "  ✓ permission_request → Permission Required"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ permission_request → expected Permission Required"
    echo "    got: $CALL"
    FAILED=$((FAILED + 1))
fi

# Session start (should be skipped)
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "session_start" '{"cwd":"/tmp/proj"}' 2>/dev/null
sleep 0.5
assert_eq "session_start skipped" "false" "$([ -s "$MOCK_LOG" ] && echo true || echo false)"

echo ""
echo "--- Deduplication ---"
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "stop" '{"cwd":"/tmp/test"}' 2>/dev/null
sleep 0.5
assert_eq "first call sends notification" "true" "$([ -s "$MOCK_LOG" ] && echo true || echo false)"

> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "stop" '{"cwd":"/tmp/test"}' 2>/dev/null
sleep 0.5
assert_eq "second call within 8s is skipped" "false" "$([ -s "$MOCK_LOG" ] && echo true || echo false)"

rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "stop" '{"cwd":"/tmp/test"}' 2>/dev/null
sleep 0.5
assert_eq "call after lock cleared succeeds" "true" "$([ -s "$MOCK_LOG" ] && echo true || echo false)"

echo ""
echo "--- Project name in title ---"
rmdir /tmp/claude-win-notify-lock 2>/dev/null || true
> "$MOCK_LOG"
bash "$SCRIPT_DIR/notify.sh" "stop" '{"cwd":"/home/user/awesome-app"}' 2>/dev/null
sleep 0.5
CALL=$(cat "$MOCK_LOG" 2>/dev/null)
if echo "$CALL" | grep -q "awesome-app"; then
    echo "  ✓ project name extracted from cwd"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ project name not in notification"
    echo "    got: $CALL"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "=== win-toast.ps1 ==="
echo ""
echo "--- Script structure ---"
if grep -q "com.anthropic.claude-code" "$SCRIPT_DIR/win-toast.ps1"; then
    echo "  ✓ uses Claude Code AppUserModelId"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ missing AppUserModelId"
    FAILED=$((FAILED + 1))
fi

if grep -q "ToastNotificationManager" "$SCRIPT_DIR/win-toast.ps1"; then
    echo "  ✓ uses Windows.UI.Notifications API"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ missing ToastNotificationManager"
    FAILED=$((FAILED + 1))
fi

# Cleanup
unset WINDIR

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -gt 0 ] && exit 1
