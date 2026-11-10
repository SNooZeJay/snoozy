# Snoozy Emerald Liquid Glass Icon & Brand Generator
#
# Uses the user's exact 4096x4096 HD transparent icon (snoozy_icon_transparent_hd.png)
# for the main app icon (`assets/icon.png`), while procedurally recreating the matching
# 1:1 Emerald Liquid Glass design for the remaining icon assets (`splash-icon.png`,
# `android-icon-background.png`, `android-icon-foreground.png`, `android-icon-monochrome.png`,
# `favicon.png`) using exact pixel-calibrated proportions from the 4096x4096 master.
#
# Run: powershell -ExecutionPolicy Bypass -File scripts/generate-logo.ps1

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$assets = Join-Path $root 'assets'
$downloadsHdIcon = 'C:\Users\Administrator\Downloads\snoozy_icon_transparent_hd.png'

function Color([string]$hex, [int]$alpha = 255) {
  $clean = $hex.TrimStart('#')
  $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
  return [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function Save-Png($bitmap, [string]$path) {
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

function New-Graphics([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  return @{ Bitmap = $bmp; Graphics = $g }
}

function New-SquirclePath([float]$x, [float]$y, [float]$w, [float]$h, [double]$n = 4.35) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $cx = $x + $w * 0.5
  $cy = $y + $h * 0.5
  $a = $w * 0.5
  $b = $h * 0.5
  $exp = 2.0 / $n
  $steps = 240
  $pts = New-Object 'System.Drawing.PointF[]' $steps
  for ($i = 0; $i -lt $steps; $i++) {
    $t = 2.0 * [Math]::PI * $i / $steps
    $cos = [Math]::Cos($t)
    $sin = [Math]::Sin($t)
    $px = $cx + [Math]::Sign($cos) * $a * [Math]::Pow([Math]::Abs($cos), $exp)
    $py = $cy + [Math]::Sign($sin) * $b * [Math]::Pow([Math]::Abs($sin), $exp)
    $pts[$i] = New-Object System.Drawing.PointF([float]$px, [float]$py)
  }
  $path.AddClosedCurve($pts, 0.25)
  return $path
}

function Fill-RadialGlow($g, [double]$cx, [double]$cy, [double]$rx, [double]$ry, [string]$hexCenter, [int]$alphaCenter, [string]$hexMid, [int]$alphaMid) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse([float]($cx - $rx), [float]($cy - $ry), [float]($rx * 2.0), [float]($ry * 2.0))
  $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $brush.CenterPoint = New-Object System.Drawing.PointF([float]$cx, [float]$cy)
  $blend = New-Object System.Drawing.Drawing2D.ColorBlend(4)
  $blend.Colors = @(
    (Color $hexMid 0),
    (Color $hexMid ([int]($alphaMid * 0.42))),
    (Color $hexMid $alphaMid),
    (Color $hexCenter $alphaCenter)
  )
  $blend.Positions = @(0.0, 0.36, 0.72, 1.0)
  $brush.InterpolationColors = $blend
  $g.FillPath($brush, $path)
  $brush.Dispose()
  $path.Dispose()
}

function Draw-EmeraldGround($g, [float]$x, [float]$y, [float]$size) {
  $rect = New-Object System.Drawing.RectangleF(($x - 2), ($y - 2), ($size + 4), ($size + 4))
  $padRect = New-Object System.Drawing.RectangleF(($x - $size * 0.5), ($y - $size * 0.5), ($size * 2.0), ($size * 2.0))

  # Exact color match to snoozy_icon_transparent_hd.png:
  # Bottom-left deep obsidian-navy (#00020F) -> Mid dark teal-slate (#0D2224) -> Top-right forest emerald (#1D6551)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $padRect,
    (Color '#1F6D57'),
    (Color '#00020E'),
    [System.Drawing.Drawing2D.LinearGradientMode]::BackwardDiagonal
  )
  $blend = New-Object System.Drawing.Drawing2D.ColorBlend(5)
  $blend.Colors = @(
    (Color '#22725B'),
    (Color '#195846'),
    (Color '#0D2F29'),
    (Color '#051118'),
    (Color '#00020F')
  )
  $blend.Positions = @(0.0, 0.28, 0.52, 0.76, 1.0)
  $bgBrush.InterpolationColors = $blend
  $g.FillRectangle($bgBrush, $rect)
  $bgBrush.Dispose()
}

function Get-TiltedOvalPoint([double]$cx, [double]$cy, [double]$rx, [double]$ry, [double]$tiltDeg, [double]$deg) {
  $tiltRad = $tiltDeg * [Math]::PI / 180.0
  $cosT = [Math]::Cos($tiltRad)
  $sinT = [Math]::Sin($tiltRad)
  $rad = $deg * [Math]::PI / 180.0
  $ex = $rx * [Math]::Cos($rad)
  $ey = $ry * [Math]::Sin($rad)
  return New-Object System.Drawing.PointF(
    [float]($cx + ($ex * $cosT - $ey * $sinT)),
    [float]($cy + ($ex * $sinT + $ey * $cosT))
  )
}

function New-UnifiedEighthNotePath([double]$size, [double]$scale = 1.0, [double]$inset = 0.0, [double]$offsetX = 0.0, [double]$offsetY = 0.0) {
  $cx = $size * 0.5 + $offsetX
  $cy = $size * 0.5 + $offsetY
  $u = $size * $scale

  # Exact pixel-measured proportions from the 4096x4096 master:
  # Left stem: [-0.0752, -0.0410], Right stem: [+0.1445, +0.1758] (slender, elegant stems!)
  $stemW     = $u * 0.0335 - $inset * 2.0
  $leftR     = $cx - $u * 0.0410 - $inset
  $leftL     = $leftR - $stemW
  $rightR    = $cx + $u * 0.1758 - $inset
  $rightL    = $rightR - $stemW

  # Top beam: topLeftY = -0.180, topRightY = -0.226, beamH = 0.098
  $topLeftY  = $cy - $u * 0.180 + $inset
  $topRightY = $cy - $u * 0.226 + $inset
  $beamH     = $u * 0.098 - $inset * 1.6

  $slope     = ($topRightY - $topLeftY) / ($rightR - $leftL)
  $innerTopL = $topLeftY + $beamH + $slope * ($leftR - $leftL)
  $innerTopR = $topLeftY + $beamH + $slope * ($rightL - $leftL)

  # Plump, rounded tilted noteheads (rx = 0.068, ry = 0.054, tilt = -28 deg)
  $headRx    = $u * 0.068 - $inset
  $headRy    = $u * 0.054 - $inset
  $tiltDeg   = -28.0
  $tiltRad   = $tiltDeg * [Math]::PI / 180.0
  $cosT      = [Math]::Cos($tiltRad)
  $sinT      = [Math]::Sin($tiltRad)

  $maxEx     = [Math]::Sqrt([Math]::Pow($headRx * $cosT, 2) + [Math]::Pow($headRy * $sinT, 2))
  $tangentDeg = [Math]::Atan2(-$headRy * $sinT, $headRx * $cosT) * 180.0 / [Math]::PI

  $leftHeadCx  = $leftR - $maxEx
  $leftHeadCy  = $cy + $u * 0.132
  $rightHeadCx = $rightR - $maxEx
  $rightHeadCy = $cy + $u * 0.086

  $neckEndDeg = 248.0
  $rTopPt = Get-TiltedOvalPoint $rightHeadCx $rightHeadCy $headRx $headRy $tiltDeg $tangentDeg
  $rNeckPt = Get-TiltedOvalPoint $rightHeadCx $rightHeadCy $headRx $headRy $tiltDeg $neckEndDeg
  $lTopPt = Get-TiltedOvalPoint $leftHeadCx $leftHeadCy $headRx $headRy $tiltDeg $tangentDeg
  $lNeckPt = Get-TiltedOvalPoint $leftHeadCx $leftHeadCy $headRx $headRy $tiltDeg $neckEndDeg

  $cornerR = [Math]::Max(1.8, $u * 0.018 - $inset * 0.45)
  $innerCornerR = [Math]::Max(1.8, $u * 0.016 - $inset * 0.35)

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath

  $lStemBotY = $lNeckPt.Y - $u * 0.032
  $path.AddLine([float]$leftL, [float]$lStemBotY, [float]$leftL, [float]($topLeftY + $cornerR))

  $tlX = $leftL + $cornerR
  $tlY = $topLeftY + $slope * $cornerR
  $path.AddBezier(
    [float]$leftL, [float]($topLeftY + $cornerR),
    [float]$leftL, [float]$topLeftY,
    [float]($leftL + $cornerR * 0.35), [float]$topLeftY,
    [float]$tlX, [float]$tlY
  )

  $trX = $rightR - $cornerR
  $trY = $topRightY - $slope * $cornerR
  $path.AddLine([float]$tlX, [float]$tlY, [float]$trX, [float]$trY)

  $path.AddBezier(
    [float]$trX, [float]$trY,
    [float]($rightR - $cornerR * 0.25), [float]$topRightY,
    [float]$rightR, [float]($topRightY + $cornerR * 0.25),
    [float]$rightR, [float]($topRightY + $cornerR)
  )

  $path.AddLine([float]$rightR, [float]($topRightY + $cornerR), [float]$rTopPt.X, [float]$rTopPt.Y)

  $rArcPts = New-Object 'System.Drawing.PointF[]' 56
  for ($i = 0; $i -lt 56; $i++) {
    $deg = $tangentDeg + ($neckEndDeg - $tangentDeg) * ($i / 55.0)
    $rArcPts[$i] = Get-TiltedOvalPoint $rightHeadCx $rightHeadCy $headRx $headRy $tiltDeg $deg
  }
  $path.AddCurve($rArcPts, 0.35)

  $rStemBotY = $rNeckPt.Y - $u * 0.032
  $path.AddBezier(
    [float]$rNeckPt.X, [float]$rNeckPt.Y,
    [float]($rightL + $u * 0.008), [float]($rNeckPt.Y - $u * 0.010),
    [float]$rightL, [float]($rNeckPt.Y - $u * 0.016),
    [float]$rightL, [float]$rStemBotY
  )

  $path.AddLine([float]$rightL, [float]$rStemBotY, [float]$rightL, [float]($innerTopR + $innerCornerR))

  $irX = $rightL - $innerCornerR
  $irY = $innerTopR - $slope * $innerCornerR
  $path.AddBezier(
    [float]$rightL, [float]($innerTopR + $innerCornerR),
    [float]$rightL, [float]$innerTopR,
    [float]($rightL - $innerCornerR * 0.35), [float]$innerTopR,
    [float]$irX, [float]$irY
  )

  $ilX = $leftR + $innerCornerR
  $ilY = $innerTopL + $slope * $innerCornerR
  $path.AddLine([float]$irX, [float]$irY, [float]$ilX, [float]$ilY)

  $path.AddBezier(
    [float]$ilX, [float]$ilY,
    [float]($leftR + $innerCornerR * 0.25), [float]$innerTopL,
    [float]$leftR, [float]($innerTopL + $innerCornerR * 0.25),
    [float]$leftR, [float]($innerTopL + $innerCornerR)
  )

  $path.AddLine([float]$leftR, [float]($innerTopL + $innerCornerR), [float]$lTopPt.X, [float]$lTopPt.Y)

  $lArcPts = New-Object 'System.Drawing.PointF[]' 56
  for ($i = 0; $i -lt 56; $i++) {
    $deg = $tangentDeg + ($neckEndDeg - $tangentDeg) * ($i / 55.0)
    $lArcPts[$i] = Get-TiltedOvalPoint $leftHeadCx $leftHeadCy $headRx $headRy $tiltDeg $deg
  }
  $path.AddCurve($lArcPts, 0.35)

  $path.AddBezier(
    [float]$lNeckPt.X, [float]$lNeckPt.Y,
    [float]($leftL + $u * 0.008), [float]($lNeckPt.Y - $u * 0.010),
    [float]$leftL, [float]($lNeckPt.Y - $u * 0.016),
    [float]$leftL, [float]$lStemBotY
  )

  $path.CloseFigure()

  return @{
    Path = $path
    LeftHead = New-Object System.Drawing.PointF([float]$leftHeadCx, [float]$leftHeadCy)
    RightHead = New-Object System.Drawing.PointF([float]$rightHeadCx, [float]$rightHeadCy)
    TopLeft = New-Object System.Drawing.PointF([float]$leftL, [float]$topLeftY)
    TopRight = New-Object System.Drawing.PointF([float]$rightR, [float]$topRightY)
    InnerLeft = New-Object System.Drawing.PointF([float]$leftR, [float]$innerTopL)
    InnerRight = New-Object System.Drawing.PointF([float]$rightL, [float]$innerTopR)
    LeftL = $leftL
    LeftR = $leftR
    RightL = $rightL
    RightR = $rightR
    HeadRx = $headRx
    HeadRy = $headRy
    Unit = $u
  }
}

function Draw-EmeraldGlassNote($g, [double]$size, [bool]$monochrome = $false, [double]$scale = 1.0) {
  $cx = [float]($size * 0.5)
  $cy = [float]($size * 0.5)
  $unit = [float]($size * $scale)

  $outer = New-UnifiedEighthNotePath $size $scale 0.0 0.0 0.0
  $inner = New-UnifiedEighthNotePath $size $scale ($unit * 0.0085) 0.0 0.0

  if ($monochrome) {
    $monoBrush = New-Object System.Drawing.SolidBrush((Color '#FFFFFF'))
    $g.FillPath($monoBrush, $outer.Path)
    $monoBrush.Dispose()
    $outer.Path.Dispose()
    $inner.Path.Dispose()
    return
  }

  # 1. Soft dark contact drop shadow cast to the bottom-left
  for ($s = 7; $s -ge 1; $s--) {
    $shOffset = $unit * 0.0045 * $s
    $shadowNote = New-UnifiedEighthNotePath $size $scale 0.0 (-$shOffset * 0.78) ($shOffset * 1.12)
    $shBrush = New-Object System.Drawing.SolidBrush((Color '#010308' ([int](32 / $s))))
    $g.FillPath($shBrush, $shadowNote.Path)
    $shBrush.Dispose()
    $shadowNote.Path.Dispose()
  }

  # 2. Internal refractive crystal glass body fill (cool icy-slate top-left to deep emerald-teal bottom-right)
  $bodyBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(($cx - $unit * 0.22), ($cy - $unit * 0.25))),
    (New-Object System.Drawing.PointF(($cx + $unit * 0.22), ($cy + $unit * 0.25))),
    (Color '#D8ECEC' 88),
    (Color '#0B3B2E' 110)
  )
  $bodyBlend = New-Object System.Drawing.Drawing2D.ColorBlend(5)
  $bodyBlend.Colors = @(
    (Color '#E2F2F2' 98),
    (Color '#7BA8A6' 52),
    (Color '#123A35' 96),
    (Color '#14493B' 88),
    (Color '#94C9C2' 82)
  )
  $bodyBlend.Positions = @(0.0, 0.26, 0.54, 0.80, 1.0)
  $bodyBrush.InterpolationColors = $bodyBlend
  $g.FillPath($bodyBrush, $outer.Path)
  $bodyBrush.Dispose()

  # 3. Clipped internal optical features
  $prevClip = $g.Clip
  $g.SetClip($outer.Path, [System.Drawing.Drawing2D.CombineMode]::Intersect)

  # 3A. Soft diagonal specular reflection sweep across the left half of the top beam
  $sheenPoly = New-Object System.Drawing.Drawing2D.GraphicsPath
  $sheenPts = [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF([float]($outer.LeftL - $unit * 0.02), [float]($outer.TopLeft.Y - $unit * 0.02))),
    (New-Object System.Drawing.PointF([float]($outer.RightR - $unit * 0.045), [float]($outer.TopRight.Y - $unit * 0.02))),
    (New-Object System.Drawing.PointF([float]($outer.LeftR + $unit * 0.045), [float]($outer.InnerLeft.Y + $unit * 0.04))),
    (New-Object System.Drawing.PointF([float]($outer.LeftL - $unit * 0.02), [float]($outer.InnerLeft.Y + $unit * 0.07)))
  )
  $sheenPoly.AddPolygon($sheenPts)
  $sheenBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF([float]$outer.LeftL, [float]$outer.TopLeft.Y)),
    (New-Object System.Drawing.PointF([float]($outer.LeftR + $unit * 0.11), [float]($outer.InnerLeft.Y + $unit * 0.04))),
    (Color '#E6F4F4' 72),
    (Color '#34D399' 0)
  )
  $g.FillPath($sheenBrush, $sheenPoly)
  $sheenBrush.Dispose()
  $sheenPoly.Dispose()

  # 3B. Deep dark obsidian-teal convex lens absorption inside both noteheads
  Fill-RadialGlow $g ($outer.LeftHead.X - $unit * 0.003) ($outer.LeftHead.Y + $unit * 0.004) ($outer.HeadRx * 0.92) ($outer.HeadRy * 0.86) '#050811' 220 '#0A1E22' 105
  Fill-RadialGlow $g ($outer.RightHead.X - $unit * 0.003) ($outer.RightHead.Y + $unit * 0.004) ($outer.HeadRx * 0.92) ($outer.HeadRy * 0.86) '#071516' 205 '#0D3028' 95

  # 3C. Top-left white-mint crescent lens highlight inside each notehead
  Fill-RadialGlow $g ($outer.LeftHead.X - $outer.HeadRx * 0.36) ($outer.LeftHead.Y - $outer.HeadRy * 0.44) ($outer.HeadRx * 0.54) ($outer.HeadRy * 0.32) '#F0FDF9' 165 '#A7F3D0' 42
  Fill-RadialGlow $g ($outer.RightHead.X - $outer.HeadRx * 0.36) ($outer.RightHead.Y - $outer.HeadRy * 0.44) ($outer.HeadRx * 0.54) ($outer.HeadRy * 0.32) '#F0FDF9' 165 '#A7F3D0' 42

  # 3D. Subtle prismatic rainbow/lime dispersion along the curved bevels
  Fill-RadialGlow $g ($outer.LeftHead.X - $outer.HeadRx * 0.36) ($outer.LeftHead.Y + $outer.HeadRy * 0.72) ($unit * 0.042) ($unit * 0.024) '#FDE047' 145 '#34D399' 42
  Fill-RadialGlow $g ($outer.LeftHead.X + $outer.HeadRx * 0.56) ($outer.LeftHead.Y + $outer.HeadRy * 0.28) ($unit * 0.038) ($unit * 0.042) '#60A5FA' 135 '#A7F3D0' 38
  Fill-RadialGlow $g ($outer.RightHead.X + $outer.HeadRx * 0.54) ($outer.RightHead.Y + $outer.HeadRy * 0.38) ($unit * 0.040) ($unit * 0.042) '#F59E0B' 115 '#34D399' 34
  Fill-RadialGlow $g ($outer.TopLeft.X + $unit * 0.038) ($outer.TopLeft.Y + $unit * 0.010) ($unit * 0.045) ($unit * 0.018) '#FB923C' 105 '#ECFDF5' 35

  $g.Clip = $prevClip

  # 4. Soft moulded glass bevel cushion (no double-outline look!)
  for ($w = 4; $w -ge 1; $w--) {
    $bevelPen = New-Object System.Drawing.Pen((Color '#CBE7E5' ([int](36 / $w))), [float]($unit * 0.0042 * $w))
    $bevelPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($bevelPen, $outer.Path)
    $bevelPen.Dispose()
  }

  # Subtle inner bevel sheen
  $innerRimBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(($cx - $unit * 0.22), ($cy - $unit * 0.24))),
    (New-Object System.Drawing.PointF(($cx + $unit * 0.22), ($cy + $unit * 0.24))),
    (Color '#ECFDF5' 115),
    (Color '#34D399' 38)
  )
  $innerRimPen = New-Object System.Drawing.Pen($innerRimBrush, [float]([Math]::Max(1.2, $unit * 0.0032)))
  $innerRimPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawPath($innerRimPen, $inner.Path)
  $innerRimPen.Dispose()
  $innerRimBrush.Dispose()

  # Crisp outer optical specular rim reflection (#ECFDF5 along top-left edges)
  $rimBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(($cx - $unit * 0.24), ($cy - $unit * 0.26))),
    (New-Object System.Drawing.PointF(($cx + $unit * 0.24), ($cy + $unit * 0.26))),
    (Color '#F0FDF9' 235),
    (Color '#7CC4B8' 125)
  )
  $rimPen = New-Object System.Drawing.Pen($rimBrush, [float]([Math]::Max(1.5, $unit * 0.0048)))
  $rimPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawPath($rimPen, $outer.Path)
  $rimPen.Dispose()
  $rimBrush.Dispose()

  # Intense top-left #ECFDF5 specular crest along the top beam & inner beam arch
  $specPen = New-Object System.Drawing.Pen((Color '#FFFFFF' 240), [float]([Math]::Max(1.5, $unit * 0.0045)))
  $specPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $specPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLine(
    $specPen,
    [float]($outer.TopLeft.X + $unit * 0.015),
    [float]($outer.TopLeft.Y + $unit * 0.005),
    [float]($outer.TopRight.X - $unit * 0.016),
    [float]($outer.TopRight.Y + $unit * 0.005)
  )
  $g.DrawLine(
    $specPen,
    [float]($outer.InnerLeft.X + $unit * 0.010),
    [float]($outer.InnerLeft.Y - $unit * 0.002),
    [float]($outer.InnerRight.X - $unit * 0.010),
    [float]($outer.InnerRight.Y - $unit * 0.002)
  )
  $specPen.Dispose()

  $outer.Path.Dispose()
  $inner.Path.Dispose()
}

function Draw-SquircleGlassBezel($g, [float]$x, [float]$y, [float]$size) {
  $outerSq = New-SquirclePath $x $y $size $size 4.35
  $innerSq = New-SquirclePath ($x + $size * 0.006) ($y + $size * 0.006) ($size * 0.988) ($size * 0.988) 4.35

  $bevelBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF($x, $y)),
    (New-Object System.Drawing.PointF(($x + $size), ($y + $size))),
    (Color '#E2F2F2' 135),
    (Color '#2B7A66' 55)
  )
  $bevelPen = New-Object System.Drawing.Pen($bevelBrush, [float]([Math]::Max(1.4, $size * 0.0048)))
  $g.DrawPath($bevelPen, $innerSq)
  $bevelPen.Dispose()
  $bevelBrush.Dispose()

  $borderPen = New-Object System.Drawing.Pen((Color '#529E8B' 65), [float]([Math]::Max(1.1, $size * 0.0022)))
  $g.DrawPath($borderPen, $outerSq)
  $borderPen.Dispose()

  $outerSq.Dispose()
  $innerSq.Dispose()
}

# 1. Main app icon, Splash icon, and Favicon: use the exact 4096x4096 HD transparent PNG from Downloads (`snoozy_icon_transparent_hd.png`)
if (Test-Path $downloadsHdIcon) {
  $hdSrc = [System.Drawing.Bitmap]::FromFile($downloadsHdIcon)
  $srcRect = New-Object System.Drawing.Rectangle(0, 0, $hdSrc.Width, $hdSrc.Height)

  # 1A. assets/icon.png (1024x1024)
  $icon = New-Graphics 1024 1024
  $dstRect1024 = New-Object System.Drawing.Rectangle(0, 0, 1024, 1024)
  $icon.Graphics.DrawImage($hdSrc, $dstRect1024, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  Save-Png $icon.Bitmap (Join-Path $assets 'icon.png')
  $icon.Graphics.Dispose()

  # 1B. assets/splash-icon.png (1024x1024 — exact 1:1 copy of the HD transparent icon)
  $splash = New-Graphics 1024 1024
  $splash.Graphics.DrawImage($hdSrc, $dstRect1024, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  Save-Png $splash.Bitmap (Join-Path $assets 'splash-icon.png')
  $splash.Graphics.Dispose()

  # 1C. assets/favicon.png (256x256 — exact 1:1 downsampled copy of the HD transparent icon)
  $fav = New-Graphics 256 256
  $dstRect256 = New-Object System.Drawing.Rectangle(0, 0, 256, 256)
  $fav.Graphics.DrawImage($hdSrc, $dstRect256, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  Save-Png $fav.Bitmap (Join-Path $assets 'favicon.png')
  $fav.Graphics.Dispose()

  # 1D. Extract the exact 3D Liquid Glass musical note from the 4096x4096 master for android-icon-foreground.png
  $fg = New-Graphics 1024 1024
  $noteClip = New-UnifiedEighthNotePath 1024 1.0 0.0 0.0 0.0
  $fg.Graphics.SetClip($noteClip.Path)
  $fg.Graphics.DrawImage($hdSrc, $dstRect1024, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $fg.Graphics.ResetClip()
  $noteClip.Path.Dispose()
  Save-Png $fg.Bitmap (Join-Path $assets 'android-icon-foreground.png')
  $fg.Graphics.Dispose()

  $hdSrc.Dispose()
  Write-Output 'Used exact snoozy_icon_transparent_hd.png for icon.png, splash-icon.png, favicon.png, and android-icon-foreground.png.'
} else {
  $icon = New-Graphics 1024 1024
  Draw-EmeraldGround $icon.Graphics 0 0 1024
  Draw-EmeraldGlassNote $icon.Graphics 1024 $false 1.0
  Save-Png $icon.Bitmap (Join-Path $assets 'icon.png')
  $icon.Graphics.Dispose()

  $splash = New-Graphics 1024 1024
  $sqClip = New-SquirclePath 130 130 764 764 4.35
  $splash.Graphics.SetClip($sqClip)
  Draw-EmeraldGround $splash.Graphics 130 130 764
  Draw-EmeraldGlassNote $splash.Graphics 1024 $false 1.0
  $splash.Graphics.ResetClip()
  Draw-SquircleGlassBezel $splash.Graphics 130 130 764
  $sqClip.Dispose()
  Save-Png $splash.Bitmap (Join-Path $assets 'splash-icon.png')
  $splash.Graphics.Dispose()

  $fav = New-Graphics 256 256
  $favSq = New-SquirclePath 16 16 224 224 4.35
  $fav.Graphics.SetClip($favSq)
  Draw-EmeraldGround $fav.Graphics 16 16 224
  Draw-EmeraldGlassNote $fav.Graphics 256 $false 1.08
  $fav.Graphics.ResetClip()
  Draw-SquircleGlassBezel $fav.Graphics 16 16 224
  $favSq.Dispose()
  Save-Png $fav.Bitmap (Join-Path $assets 'favicon.png')
  $fav.Graphics.Dispose()

  $fg = New-Graphics 1024 1024
  Draw-EmeraldGlassNote $fg.Graphics 1024 $false 0.92
  Save-Png $fg.Bitmap (Join-Path $assets 'android-icon-foreground.png')
  $fg.Graphics.Dispose()
}

# 2. Android adaptive background & monochrome layers
$bg = New-Graphics 1024 1024
Draw-EmeraldGround $bg.Graphics 0 0 1024
Save-Png $bg.Bitmap (Join-Path $assets 'android-icon-background.png')
$bg.Graphics.Dispose()

$mono = New-Graphics 1024 1024
Draw-EmeraldGlassNote $mono.Graphics 1024 $true 1.0
Save-Png $mono.Bitmap (Join-Path $assets 'android-icon-monochrome.png')
$mono.Graphics.Dispose()

Write-Output 'Generated 1:1 icon suite from snoozy_icon_transparent_hd.png.'
