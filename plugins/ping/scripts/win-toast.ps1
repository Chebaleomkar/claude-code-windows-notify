param(
    [string]$Title = "Claude Code",
    [string]$Body = "Task complete"
)

$appId = "com.ping.claude-code"
$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$appId"
$iconSmall = "$PSScriptRoot\icon-small.png"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath -Name "DisplayName" -Value "Ping" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath -Name "ShowInSettings" -Value 1 -PropertyType DWord -Force | Out-Null
if (Test-Path $iconSmall) {
    New-ItemProperty -Path $regPath -Name "IconUri" -Value $iconSmall -PropertyType ExpandString -Force | Out-Null
}

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$iconLarge = "$PSScriptRoot\claude-icon.png"

$logoTag = ""
if (Test-Path $iconLarge) {
    $logoTag = "<image placement=`"appLogoOverride`" src=`"$iconLarge`" hint-crop=`"circle`"/>"
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

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
