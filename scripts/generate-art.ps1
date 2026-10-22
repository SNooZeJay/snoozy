Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$assets = Join-Path $root 'assets'
$covers = Join-Path $assets 'covers'
New-Item -ItemType Directory -Force -Path $covers | Out-Null

function Color([string]$hex, [int]$alpha = 255) {
  $clean = $hex.TrimStart('#')
  $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
  return [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function New-Gradient([int]$w, [int]$h, [string]$top, [string]$bottom, [float]$angle = 90) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (Color $top), (Color $bottom), $angle)
  $g.FillRectangle($brush, $rect)
  $brush.Dispose()
  return @{ Bitmap = $bmp; Graphics = $g; Width = $w; Height = $h }
}

function Add-Grain($g, [int]$w, [int]$h, [int]$seed, [int]$count, [int]$alpha = 16) {
  $rng = New-Object System.Random($seed)
  for ($i = 0; $i -lt $count; $i++) {
    $x = $rng.Next(0, $w)
    $y = $rng.Next(0, $h)
    $a = $rng.Next(2, $alpha + 1)
    $tone = if ($rng.NextDouble() -gt 0.45) { 255 } else { 8 }
    $brush = New-Object System.Drawing.SolidBrush((Color '#FFFFFF' $a))
    if ($tone -eq 8) { $brush.Color = (Color '#000000' $a) }
    $g.FillEllipse($brush, $x, $y, 1, 1)
    $brush.Dispose()
  }
}

function Add-Vignette($g, [int]$w, [int]$h, [int]$alpha = 150) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(-120, -80, $w + 240, $h + 160)
  $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $brush.CenterColor = (Color '#000000' 0)
  $brush.SurroundColors = @((Color '#000000' $alpha))
  $brush.FocusScales = New-Object System.Drawing.PointF(0.55, 0.55)
  $g.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()
}

function Add-Stars($g, [int]$w, [int]$h, [int]$seed, [int]$count, [string]$tint = '#F5F0DB') {
  $rng = New-Object System.Random($seed)
  for ($i = 0; $i -lt $count; $i++) {
    $x = $rng.Next(10, $w - 10)
    $y = $rng.Next(10, [int]($h * 0.72))
    $r = if ($rng.NextDouble() -gt 0.86) { 2.3 } else { 0.8 + $rng.NextDouble() * 1.2 }
    $a = 30 + $rng.Next(0, 110)
    $brush = New-Object System.Drawing.SolidBrush((Color $tint $a))
    $g.FillEllipse($brush, $x, $y, $r, $r)
    $brush.Dispose()
  }
}

function Save-Png($bitmap, [string]$path) {
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

function New-CoverRain() {
  $c = New-Gradient 600 600 '#081712' '#183A2E' 90
  $g = $c.Graphics
  Add-Stars $g 600 600 11 40

  # Moon, half veiled by the trees.
  $glow = New-Object System.Drawing.SolidBrush((Color '#D7F2C4' 18))
  $g.FillEllipse($glow, 390, 70, 180, 180)
  $g.FillEllipse($glow, 420, 100, 120, 120)
  $glow.Dispose()
  $moon = New-Object System.Drawing.SolidBrush((Color '#EFEBD8' 235))
  $g.FillEllipse($moon, 448, 125, 64, 64)
  $moon.Dispose()

  # Rain falling in uneven, fine strokes.
  $rng = New-Object System.Random(13)
  for ($i = 0; $i -lt 92; $i++) {
    $x = $rng.Next(0, 600)
    $y = $rng.Next(0, 430)
    $len = $rng.Next(18, 76)
    $a = $rng.Next(14, 54)
    $pen = New-Object System.Drawing.Pen((Color '#BCE4D0' $a), 1)
    $g.DrawLine($pen, $x, $y, $x - 5, $y + $len)
    $pen.Dispose()
  }

  # Layered fir silhouettes.
  $treeRng = New-Object System.Random(17)
  for ($layer = 0; $layer -lt 4; $layer++) {
    $baseY = 430 + $layer * 44
    $treeColor = @('#0A1D16', '#0C241B', '#0E2A20', '#102F24')[$layer]
    for ($t = -1; $t -lt 11; $t++) {
      $x = $t * 72 + $treeRng.Next(-18, 20)
      $h = 130 + $treeRng.Next(0, 130)
      $w = 60 + $treeRng.Next(0, 34)
      $points = @(
        (New-Object System.Drawing.PointF(($x + $w / 2), ($baseY - $h))),
        (New-Object System.Drawing.PointF(($x + $w), $baseY)),
        (New-Object System.Drawing.PointF($x, $baseY))
      )
      $brush = New-Object System.Drawing.SolidBrush((Color $treeColor 235))
      $g.FillPolygon($brush, $points)
      $brush.Dispose()
    }
  }

  # Ground fog.
  $fog = New-Object System.Drawing.SolidBrush((Color '#A7DCC4' 14))
  $g.FillRectangle($fog, 0, 470, 600, 90)
  $fog.Dispose()
  Add-Grain $g 600 600 5 9500 18
  Add-Vignette $g 600 600 135
  Save-Png $c.Bitmap (Join-Path $covers 'rain-on-fir.png')
}

function New-CoverTide() {
  $c = New-Gradient 600 600 '#061521' '#1C4055' 90
  $g = $c.Graphics
  Add-Stars $g 600 600 22 68 '#E8F4F6'

  $glow = New-Object System.Drawing.SolidBrush((Color '#C7E6E8' 18))
  $g.FillEllipse($glow, 150, 30, 320, 320)
  $glow.Dispose()
  $moon = New-Object System.Drawing.SolidBrush((Color '#EEF1E4' 230))
  $g.FillEllipse($moon, 248, 78, 104, 104)
  $moon.Dispose()

  # Horizontal water bands, getting denser toward the bottom.
  for ($i = 0; $i -lt 24; $i++) {
    $y = 245 + $i * 15
    $alpha = 16 + [int]($i * 3.2)
    $pen = New-Object System.Drawing.Pen((Color '#B4DDE1' $alpha), (1 + ($i % 3) * 0.4))
    $g.DrawLine($pen, 0, $y, 600, $y)
    $pen.Dispose()
  }

  # The moon path on the water.
  $rng = New-Object System.Random(27)
  for ($i = 0; $i -lt 18; $i++) {
    $y = 260 + $i * 17
    $w = 70 + $i * 9 + $rng.Next(-14, 16)
    $x = 300 - $w / 2 + $rng.Next(-10, 11)
    $a = 105 - $i * 4
    if ($a -lt 10) { $a = 10 }
    $pen = New-Object System.Drawing.Pen((Color '#E9EFE0' $a), 2.2)
    $g.DrawLine($pen, $x, $y, $x + $w, $y)
    $pen.Dispose()
  }

  # Foam crests.
  $foamRng = New-Object System.Random(31)
  for ($i = 0; $i -lt 9; $i++) {
    $y = 430 + $foamRng.Next(0, 140)
    $x = $foamRng.Next(0, 520)
    $w = $foamRng.Next(40, 120)
    $pen = New-Object System.Drawing.Pen((Color '#C8E8E4' (20 + $foamRng.Next(0, 35))), 1.4)
    $g.DrawArc($pen, $x, $y, $w, 22, 195, 150)
    $pen.Dispose()
  }

  Add-Grain $g 600 600 9 8500 16
  Add-Vignette $g 600 600 125
  Save-Png $c.Bitmap (Join-Path $covers 'low-tide.png')
}

function New-CoverAir() {
  $c = New-Gradient 600 600 '#171A13' '#33382A' 55
  $g = $c.Graphics
  Add-Stars $g 600 600 44 82 '#F2EACF'

  # Soft moon low in the sky.
  $moonGlow = New-Object System.Drawing.SolidBrush((Color '#E6E3C2' 15))
  $g.FillEllipse($moonGlow, 380, 315, 190, 190)
  $moonGlow.Dispose()
  $moon = New-Object System.Drawing.SolidBrush((Color '#E8E3C8' 185))
  $g.FillEllipse($moon, 443, 374, 66, 66)
  $moon.Dispose()

  # Wind drawn as long, translucent curves.
  $rng = New-Object System.Random(57)
  for ($i = 0; $i -lt 17; $i++) {
    $y = 80 + $i * 26 + $rng.Next(-12, 12)
    $pen = New-Object System.Drawing.Pen((Color '#DAD9B8' (12 + $rng.Next(0, 23))), (1 + $rng.NextDouble() * 1.7))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier(-40, $y, 150, $y - 65, 390, $y + 75, 650, $y - 20)
    $g.DrawPath($pen, $path)
    $path.Dispose()
    $pen.Dispose()
  }

  # Tall grass silhouette, moving with the wind.
  for ($i = 0; $i -lt 32; $i++) {
    $x = 10 + $i * 19 + $rng.Next(-6, 7)
    $h = 35 + $rng.Next(0, 85)
    $bend = $rng.Next(-15, 24)
    $pen = New-Object System.Drawing.Pen((Color '#0B160E' 210), (1 + $rng.NextDouble()))
    $g.DrawBezier($pen, $x, 600, $x + $bend / 3, 570 - $h / 2, $x + $bend, 530 - $h, $x + $bend + 7, 505 - $h)
    $pen.Dispose()
  }

  Add-Grain $g 600 600 15 9800 18
  Add-Vignette $g 600 600 140
  Save-Png $c.Bitmap (Join-Path $covers 'night-air.png')
}

function New-CoverHearth() {
  $c = New-Gradient 600 600 '#150B08' '#4A2415' 90
  $g = $c.Graphics
  Add-Stars $g 600 600 66 31 '#F4D3A5'

  # Ember glow behind everything.
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(62, 250, 476, 430)
  $glow = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $glow.CenterColor = (Color '#F0A35A' 120)
  $glow.SurroundColors = @((Color '#5A2213' 0))
  $g.FillPath($glow, $path)
  $glow.Dispose()
  $path.Dispose()

  # Stacked logs, abstracted.
  $rng = New-Object System.Random(68)
  for ($i = 0; $i -lt 5; $i++) {
    $y = 430 + $i * 26
    $pen = New-Object System.Drawing.Pen((Color '#1D0D08' 235), 18)
    $g.DrawLine($pen, 70 + $rng.Next(-20, 20), $y, 530 + $rng.Next(-20, 20), $y + $rng.Next(-14, 14))
    $pen.Dispose()
    $ember = New-Object System.Drawing.SolidBrush((Color '#FFBD73' (20 + $rng.Next(0, 40))))
    $g.FillEllipse($ember, 200 + $rng.Next(0, 200), $y + 3, 4, 4)
    $ember.Dispose()
  }

  # Flame shapes.
  for ($i = 0; $i -lt 9; $i++) {
    $x = 205 + $i * 24 + $rng.Next(-12, 12)
    $h = 70 + $rng.Next(0, 170)
    $w = 24 + $rng.Next(0, 24)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $ctrlY = 410 - $h * 0.35
    $path.AddBezier($x, 425, ($x - $w), $ctrlY, ($x + $w * 0.2), (355 - $h), $x + 5, (402 - $h))
    $path.AddBezier($x + 5, (402 - $h), $x + $w * 0.9, (390 - $h * 0.35), $x + $w, 398, $x, 425)
    $brush = New-Object System.Drawing.SolidBrush((Color '#FFB768' (18 + $rng.Next(0, 25))))
    $g.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
  }

  # Sparks.
  for ($i = 0; $i -lt 48; $i++) {
    $x = 120 + $rng.Next(0, 360)
    $y = 170 + $rng.Next(0, 250)
    $r = 0.8 + $rng.NextDouble() * 1.8
    $brush = New-Object System.Drawing.SolidBrush((Color '#FFD59B' (30 + $rng.Next(0, 110))))
    $g.FillEllipse($brush, $x, $y, $r, $r)
    $brush.Dispose()
  }

  Add-Grain $g 600 600 21 9000 18
  Add-Vignette $g 600 600 150
  Save-Png $c.Bitmap (Join-Path $covers 'hearth.png')
}

function New-CoverDrift() {
  $c = New-Gradient 600 600 '#0D0B1D' '#251D3A' 70
  $g = $c.Graphics
  Add-Stars $g 600 600 88 150 '#EDE9FF'

  # Huge quiet planet.
  $planetGlow = New-Object System.Drawing.SolidBrush((Color '#B8A9E8' 18))
  $g.FillEllipse($planetGlow, 105, 250, 420, 420)
  $planetGlow.Dispose()
  $planet = New-Object System.Drawing.SolidBrush((Color '#6F6796' 160))
  $g.FillEllipse($planet, 175, 318, 290, 290)
  $planet.Dispose()
  $planetShade = New-Object System.Drawing.SolidBrush((Color '#1A1530' 110))
  $g.FillEllipse($planetShade, 255, 318, 210, 290)
  $planetShade.Dispose()

  # Orbital rings.
  for ($i = 0; $i -lt 4; $i++) {
    $pen = New-Object System.Drawing.Pen((Color '#D8CCFF' (18 + $i * 10)), 1.2)
    $g.DrawEllipse($pen, 70 - $i * 22, 300 - $i * 8, 460 + $i * 44, 150 + $i * 16)
    $pen.Dispose()
  }

  # Tiny drifting particles.
  $rng = New-Object System.Random(99)
  for ($i = 0; $i -lt 80; $i++) {
    $x = $rng.Next(0, 600)
    $y = $rng.Next(0, 600)
    $r = 0.6 + $rng.NextDouble() * 1.5
    $brush = New-Object System.Drawing.SolidBrush((Color '#DAD2FF' (12 + $rng.Next(0, 65))))
    $g.FillEllipse($brush, $x, $y, $r, $r)
    $brush.Dispose()
  }

  Add-Grain $g 600 600 33 7000 15
  Add-Vignette $g 600 600 160
  Save-Png $c.Bitmap (Join-Path $covers 'deep-drift.png')
}

function Add-Mark($g, [int]$size, [bool]$transparent, [string]$ink = '#F2EEDC') {
  $cx = $size / 2
  $cy = $size / 2 - $size * 0.015
  $outer = $size * 0.285
  $cut = $size * 0.255
  $offsetX = $size * 0.098
  $offsetY = -$size * 0.075

  if (-not $transparent) {
    $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath.AddEllipse($cx - $outer * 1.7, $cy - $outer * 1.7, $outer * 3.4, $outer * 3.4)
    $glow = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
    $glow.CenterColor = (Color '#D7F2C4' 42)
    $glow.SurroundColors = @((Color '#D7F2C4' 0))
    $g.FillPath($glow, $glowPath)
    $glow.Dispose()
    $glowPath.Dispose()
  }

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.FillMode = [System.Drawing.Drawing2D.FillMode]::Alternate
  $path.AddEllipse($cx - $outer, $cy - $outer, $outer * 2, $outer * 2)
  $path.AddEllipse($cx - $outer + $offsetX, $cy - $outer + $offsetY, $cut * 2, $cut * 2)
  $brush = New-Object System.Drawing.SolidBrush((Color $ink 255))
  $g.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()

  # Three quiet waves beneath the moon.
  $baseY = $cy + $outer * 1.32
  for ($i = 0; $i -lt 3; $i++) {
    $pen = New-Object System.Drawing.Pen((Color $ink (150 - $i * 38)), [Math]::Max(2, $size * 0.006))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $y = $baseY + $i * $size * 0.037
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($cx - $outer * 0.95, $y, $cx - $outer * 0.35, $y - $size * 0.035, $cx + $outer * 0.1, $y + $size * 0.025, $cx + $outer * 0.95, $y - $size * 0.008)
    $g.DrawPath($pen, $path)
    $path.Dispose()
    $pen.Dispose()
  }
}

function New-AppIcon([string]$path, [bool]$transparent, [bool]$mono) {
  $size = 1024
  if ($transparent) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
  } else {
    $c = New-Gradient $size $size '#06110D' '#0E2319' 90
    $bmp = $c.Bitmap
    $g = $c.Graphics
    Add-Stars $g $size $size 123 110 '#E8EED8'
    $fog = New-Object System.Drawing.SolidBrush((Color '#6E9D7D' 12))
    $g.FillEllipse($fog, -150, 620, 1324, 560)
    $fog.Dispose()
  }
  if ($transparent) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  }
  if ($mono) {
    Add-Mark $g $size $true '#FFFFFF'
    # Monochrome adaptive icons are masked; no glow or color.
    Add-Grain $g $size $size 77 2200 10
  } else {
    Add-Mark $g $size $transparent '#F2EEDC'
    if (-not $transparent) {
      Add-Grain $g $size $size 12 6500 13
    }
  }
  Save-Png $bmp $path
}

function New-Splash() {
  $size = 1024
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  Add-Mark $g $size $true '#F2EEDC'
  Save-Png $bmp (Join-Path $assets 'splash-icon.png')
}

New-CoverRain
New-CoverTide
New-CoverAir
New-CoverHearth
New-CoverDrift
New-AppIcon (Join-Path $assets 'icon.png') $false $false
New-AppIcon (Join-Path $assets 'android-icon-foreground.png') $true $false
New-AppIcon (Join-Path $assets 'android-icon-monochrome.png') $true $true
New-Splash

# Solid-ish adaptive background, with a faint horizon. Android crops this independently.
$bg = New-Gradient 1024 1024 '#06110D' '#0D2117' 90
$bg.Graphics.FillEllipse((New-Object System.Drawing.SolidBrush((Color '#47745B' 18))), -300, 500, 1624, 800)
$bg.Graphics.FillEllipse((New-Object System.Drawing.SolidBrush((Color '#A6C7A5' 8))), 200, 730, 624, 200)
Add-Grain $bg.Graphics 1024 1024 55 4200 10
Save-Png $bg.Bitmap (Join-Path $assets 'android-icon-background.png')

# Favicon
$fav = New-Gradient 256 256 '#06110D' '#0E2319' 90
Add-Mark $fav.Graphics 256 $false '#F2EEDC'
Save-Png $fav.Bitmap (Join-Path $assets 'favicon.png')

Write-Output 'Generated covers, icon, adaptive layers, splash, and favicon.'
