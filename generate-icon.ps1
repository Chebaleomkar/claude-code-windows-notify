# Generate a 256x256 ICO icon for Claude Code Windows notifications
# Icon: bell shape with purple-teal gradient, red notification dot, code brackets

Add-Type -AssemblyName System.Drawing

$size = 256
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)

# --- Bell body (gradient fill) ---
$bellRect = New-Object System.Drawing.Rectangle(58, 40, 140, 150)
$gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bellRect,
    [System.Drawing.Color]::FromArgb(255, 128, 90, 213),   # purple
    [System.Drawing.Color]::FromArgb(255, 56, 178, 172),    # teal
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)

# Bell outline path
$bellPath = New-Object System.Drawing.Drawing2D.GraphicsPath

# Top dome of the bell
$bellPath.AddArc(68, 45, 120, 120, 180, 180)

# Sides flaring out at bottom
$bellPath.AddLine(188, 105, 205, 170)
$bellPath.AddLine(205, 170, 210, 185)
$bellPath.AddArc(48, 180, 160, 20, 0, 180)
$bellPath.CloseFigure()

$g.FillPath($gradBrush, $bellPath)

# Bell rim at bottom
$rimBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 100, 70, 190))
$g.FillEllipse($rimBrush, 48, 178, 160, 22)

# Clapper (small circle at very bottom)
$clapperBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 80, 60, 170))
$g.FillEllipse($clapperBrush, 108, 198, 40, 30)

# Small knob on top of bell
$knobBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 110, 80, 200))
$g.FillEllipse($knobBrush, 118, 30, 20, 20)

# --- Code brackets < > ---
$bracketFont = New-Object System.Drawing.Font("Consolas", 42, [System.Drawing.FontStyle]::Bold)
$bracketBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 255, 255))

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center

# Left bracket <
$leftRect = New-Object System.Drawing.RectangleF(5, 90, 55, 60)
$g.DrawString("<", $bracketFont, $bracketBrush, $leftRect, $sf)

# Right bracket >
$rightRect = New-Object System.Drawing.RectangleF(196, 90, 55, 60)
$g.DrawString(">", $bracketFont, $bracketBrush, $rightRect, $sf)

# --- Red notification dot ---
$dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 239, 68, 68))
$g.FillEllipse($dotBrush, 180, 28, 48, 48)

# White highlight on dot
$highlightBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 255, 255, 255))
$g.FillEllipse($highlightBrush, 190, 34, 16, 16)

# --- Clean up graphics ---
$g.Dispose()
$gradBrush.Dispose()

# --- Convert to ICO ---
$outDir = "$PSScriptRoot\plugins\windows-notify\scripts"
if (-not (Test-Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}
$icoPath = "$outDir\icon.ico"

# ICO file format: header + directory entry + PNG data
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()
$ms.Dispose()

# Build ICO file manually
$ico = New-Object System.IO.MemoryStream

# ICO Header (6 bytes)
$writer = New-Object System.IO.BinaryWriter($ico)
$writer.Write([UInt16]0)      # reserved
$writer.Write([UInt16]1)      # type: ICO
$writer.Write([UInt16]1)      # number of images

# ICO Directory Entry (16 bytes)
$writer.Write([byte]0)        # width (0 = 256)
$writer.Write([byte]0)        # height (0 = 256)
$writer.Write([byte]0)        # color palette
$writer.Write([byte]0)        # reserved
$writer.Write([UInt16]1)      # color planes
$writer.Write([UInt16]32)     # bits per pixel
$writer.Write([UInt32]$pngBytes.Length)  # image size
$writer.Write([UInt32]22)     # offset to image data (6 header + 16 entry)

# PNG image data
$writer.Write($pngBytes)
$writer.Flush()

# Write to file
[System.IO.File]::WriteAllBytes($icoPath, $ico.ToArray())

$writer.Dispose()
$ico.Dispose()
$bmp.Dispose()

Write-Host "Icon generated: $icoPath"
