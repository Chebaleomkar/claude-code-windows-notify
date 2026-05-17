# Ping

**Native Windows desktop notifications for Claude Code — works with any terminal.**

Ping is a Claude Code plugin that sends Windows toast notifications when Claude completes a task, needs input, or requires permission. Works with **any terminal** — Warp, Windows Terminal, CMD, PowerShell, Git Bash, or anything else.

## Why?

Claude Code has no built-in notification support on Windows. When you switch to another window while Claude works, you have no way to know when it finishes. Ping fixes that with native Windows toast notifications.

## Install

```bash
claude plugin marketplace add Chebaleomkar/claude-code-ping
claude plugin install ping@claude-code-ping
```

Then restart Claude Code. You'll see:
```
🔔 Windows notifications active. You'll receive desktop toasts when tasks complete or input is needed.
```

## Notifications

| Event | Toast Title | When |
|-------|------------|------|
| ✅ Task Completed | `✅ Task Completed — project-name` | Claude finishes processing |
| ⏳ Input Needed | `⏳ Input Needed — project-name` | Claude is waiting for your response |
| 🔐 Permission Required | `🔐 Permission Required — project-name` | Claude needs approval to run a tool |

Each notification includes the **project name** (extracted from your working directory) so you know which terminal tab needs attention.

## Features

- **Zero dependencies** — uses built-in Windows 10/11 `[Windows.UI.Notifications]` API
- **Any terminal** — not tied to Warp or any specific terminal emulator
- **Smart deduplication** — one notification per event, even when multiple hooks fire
- **Context-aware** — shows project name and relevant details (tool name, task summary)
- **Transcript summaries** — task completion notifications include what Claude did
- **Non-blocking** — notifications fire in the background, never slow down Claude

## How It Works

```
Claude Code event (Stop / Notification / PermissionRequest)
    │
    ├── on-stop.sh / on-notification.sh / on-permission-request.sh
    │       │
    │       └── notify.sh
    │               │
    │               ├── Check: is this Windows? (exit if not)
    │               ├── Deduplication: mkdir atomic lock (8s window)
    │               ├── Extract: event type + project name from hook JSON
    │               ├── Build: title + body based on event type
    │               └── Send: PowerShell → win-toast.ps1
    │                       │
    │                       ├── Register com.anthropic.claude-code as app
    │                       └── Windows.UI.Notifications.ToastNotification
    │
    └── Native Windows toast appears 🎉
```

## Requirements

- Windows 10 or 11
- Claude Code CLI
- PowerShell (included with Windows)
- [jq](https://jqlang.github.io/jq/) (optional — for rich notification content)
  ```bash
  choco install jq    # via Chocolatey
  winget install jqlang.jq   # via WinGet
  ```

## Testing

Run the test suite:

```bash
bash plugins/ping/tests/test-notify.sh
```

Tests use a mock PowerShell — no actual notifications are sent. Safe to run anywhere.

## Uninstall

```bash
claude plugin uninstall ping@claude-code-ping
```

## Troubleshooting

**No notification appears:**
1. Check Windows Settings → System → Notifications → enabled
2. Check Focus Assist / Do Not Disturb is off
3. Test manually:
   ```bash
   powershell -ExecutionPolicy Bypass -File ~/.claude/plugins/cache/claude-code-ping/ping/*/scripts/win-toast.ps1 -Title "Test" -Body "Hello"
   ```

**Multiple notifications per event:**
Remove stale lock: `rmdir /tmp/claude-win-notify-lock`

**Plugin not activating:**
Check it's enabled: look for `"ping@claude-code-ping": true` in `~/.claude/settings.json`

## Related

- [Warp-specific notification fix](https://github.com/Chebaleomkar/claude-warp-win-notify) — patches the Warp plugin specifically
- [Upstream Warp PR](https://github.com/warpdotdev/claude-code-warp/pull/50) — contributed Windows support to the official Warp plugin
- [Blog: How I Fixed Windows Notifications for Claude Code](https://omkarchebale.vercel.app/blogs/how-i-fixed-windows-notifications-for-claude-code-s-warp-plugin)

## License

MIT — see [LICENSE](LICENSE)
