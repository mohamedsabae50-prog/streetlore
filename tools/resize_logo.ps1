$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = "D:\codes\streetlore\assets\logo\streetlore_logo.png"
$img = [System.Drawing.Image]::FromFile($src)
$origW = $img.Width
$origH = $img.Height
Write-Host "Source: ${origW}x${origH}"

# Android launcher densities
$densities = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($d in $densities.GetEnumerator()) {
    $dir = "D:\codes\streetlore\android\app\src\main\res\$($d.Key)"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp = New-Object System.Drawing.Bitmap($d.Value, $d.Value)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $d.Value, $d.Value)
    $g.Dispose()
    $target = "$dir\ic_launcher.png"
    $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Saved: $target ($($d.Value)x$($d.Value))"
}

$img.Dispose()
Write-Host "Done."
