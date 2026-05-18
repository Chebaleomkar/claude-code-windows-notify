Add-Type -AssemblyName System.Drawing

$size = 128
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.TextRenderingHint = 'AntiAliasGridFit'

# Dark background
$g.Clear([System.Drawing.Color]::FromArgb(24, 24, 27))

# Claude's warm terracotta/orange color
$claudeColor = [System.Drawing.Color]::FromArgb(217, 119, 87)
$pen = New-Object System.Drawing.Pen $claudeColor, 8
$pen.StartCap = 'Round'
$pen.EndCap = 'Round'

# Draw a clean ">" prompt symbol — represents Claude Code CLI
$g.DrawLine($pen, 30, 40, 64, 64)
$g.DrawLine($pen, 64, 64, 30, 88)

# Cursor line after prompt
$cursorPen = New-Object System.Drawing.Pen $claudeColor, 6
$cursorPen.StartCap = 'Round'
$cursorPen.EndCap = 'Round'
$g.DrawLine($cursorPen, 76, 88, 100, 88)

$g.Dispose()

$outPath = Join-Path $PSScriptRoot "claude-icon.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Saved: $outPath"
