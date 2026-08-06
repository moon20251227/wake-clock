Add-Type -AssemblyName System.Drawing

function New-Icon {
  param([int]$size, [string]$path)
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::FromArgb(255, 20, 20, 31))

  $cx = [single]($size / 2.0)
  $cy = [single]($size / 2.0)
  $R  = [single]($size * 0.40)

  $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 139, 124, 246), [single][Math]::Max(1, [double]($size * 0.05)))
  $g.DrawEllipse($ringPen, $cx - $R, $cy - $R, 2 * $R, 2 * $R)
  $ringPen.Dispose()

  $penP = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 139, 124, 246), [single][Math]::Max(1, [double]($size * 0.045)))
  $penW = New-Object System.Drawing.Pen([System.Drawing.Color]::White, [single][Math]::Max(1, [double]($size * 0.03)))
  $penP.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $penW.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

  $L1 = [single]($size * 0.42)
  $L2 = [single]($size * 0.30)
  $a1 = -30.0 * [Math]::PI / 180.0
  $a2 = -150.0 * [Math]::PI / 180.0
  $g.DrawLine($penP, $cx, $cy, $cx + $L1 * [Math]::Sin($a1), $cy - $L1 * [Math]::Cos($a1))
  $g.DrawLine($penW, $cx, $cy, $cx + $L2 * [Math]::Sin($a2), $cy - $L2 * [Math]::Cos($a2))
  $penP.Dispose(); $penW.Dispose()

  $d = [single]($size * 0.03)
  $dot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $g.FillEllipse($dot, $cx - $d, $cy - $d, 2 * $d, 2 * $d)
  $dot.Dispose()

  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output ("icon " + $size + " done")
}

New-Item -ItemType Directory -Force "D:\wake-clock\icons" | Out-Null
New-Icon 192 "D:\wake-clock\icons\icon-192.png"
New-Icon 512 "D:\wake-clock\icons\icon-512.png"
Write-Output "all done"
