# Native Windows toast notification for Claude Code
# Works with any terminal — no Warp dependency
#
# Usage: powershell -ExecutionPolicy Bypass -File win-toast.ps1 -Title "title" -Body "body"

param(
    [string]$Title = "Claude Code",
    [string]$Body = "Task complete"
)

# --- Register Claude Code as a notification source ---
$appId = "com.anthropic.claude-code"
$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$appId"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath -Name "ShowInSettings" -Value 1 -PropertyType DWord -Force | Out-Null

# --- Generate icon PNG if not present ---
$iconPath = "$PSScriptRoot\icon.png"
if (-not (Test-Path $iconPath)) {
    Add-Type -AssemblyName System.Drawing
    $size = 64
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point 0, 0),
        (New-Object System.Drawing.Point $size, $size),
        [System.Drawing.Color]::FromArgb(108, 99, 255),
        [System.Drawing.Color]::FromArgb(78, 205, 196)
    )
    $g.FillEllipse($brush, 2, 2, $size-4, $size-4)

    $font = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'
    $sf.LineAlignment = 'Center'
    $g.DrawString('C', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 0, $size, $size), $sf)

    $g.FillEllipse([System.Drawing.Brushes]::Red, 44, 2, 16, 16)
    $g.Dispose()
    $bmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# --- Load Windows Runtime types ---
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

# --- Build toast XML with inline icon ---
$logoTag = ""
if (Test-Path $iconPath) {
    $logoTag = "<image placement=`"appLogoOverride`" src=`"$iconPath`" hint-crop=`"circle`"/>"
}

$toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      $logoTag
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
