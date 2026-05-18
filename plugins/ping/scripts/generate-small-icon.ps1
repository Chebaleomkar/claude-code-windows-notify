Add-Type -AssemblyName System.Drawing

$size = 64
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'HighQuality'
$g.TextRenderingHint = 'AntiAliasGridFit'

# Dark background circle
$g.Clear([System.Drawing.Color]::FromArgb(18, 18, 18))
$bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(18, 18, 18))
$g.FillEllipse($bgBrush, 0, 0, $size-1, $size-1)

# Green ">" chevron — bold, centered, unmistakable at small size
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(72, 209, 160)), 5
$pen.StartCap = 'Round'
$pen.EndCap = 'Round'
$pen.LineJoin = 'Round'

# Draw ">" shape
$g.DrawLine($pen, 20, 16, 42, 32)
$g.DrawLine($pen, 42, 32, 20, 48)

# Small ping dot (top-right)
$dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(72, 209, 160))
$g.FillEllipse($dotBrush, 46, 8, 8, 8)

$g.Dispose()

$outPath = Join-Path $PSScriptRoot "icon-small.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Saved: $outPath"
