# Native Windows toast notification for Claude Code
# Works with any terminal — no Warp dependency
#
# Usage: powershell -ExecutionPolicy Bypass -File win-toast.ps1 -Title "title" -Body "body"

param(
    [string]$Title = "Claude Code",
    [string]$Body = "Task complete"
)

# --- Register Claude Code as a notification source (one-time, no admin needed) ---
$appId = "com.anthropic.claude-code"
$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$appId"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath -Name "ShowInSettings" -Value 1 -PropertyType DWord -Force | Out-Null

# Use the plugin's own icon
$iconPath = "$PSScriptRoot\icon.ico"
if (Test-Path $iconPath) {
    New-ItemProperty -Path $regPath -Name "IconUri" -Value $iconPath -PropertyType ExpandString -Force | Out-Null
}

# --- Load Windows Runtime types ---
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

# --- Build toast XML ---
$toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Body</text>
    </binding>
  </visual>
</toast>
"@

# --- Show notification ---
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
