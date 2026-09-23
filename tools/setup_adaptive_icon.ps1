$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# 1) Build a proper adaptive-icon foreground with the safe-zone
#    respected. Android launchers apply a mask (circle, squircle,
#    teardrop, square) so the visible content must fit within the
#    central 66dp circle of the 108dp layer. We:
#      - take the 1024x1024 brand logo
#      - shrink it down so the design fits inside ~280 px
#      - place it centered on a 432x432 transparent canvas so the
#        outer 76 px on every side (19 dp at xxxhdpi) is fully
#        transparent. The launcher mask can crop up to 19 dp from
#        each edge without losing any logo detail.
$src = "D:\codes\streetlore\assets\logo\streetlore_logo.png"

$canvas = 432
$logoSide = 280
$offsetX = ($canvas - $logoSide) / 2
$offsetY = ($canvas - $logoSide) / 2

$bmp = New-Object System.Drawing.Bitmap($canvas, $canvas)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$srcImg = [System.Drawing.Image]::FromFile($src)
$g.DrawImage($srcImg, $offsetX, $offsetY, $logoSide, $logoSide)
$g.Dispose()
$srcImg.Dispose()

$dst = "D:\codes\streetlore\android\app\src\main\res\drawable\ic_launcher_foreground.png"
$bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Foreground (with safe zone): $dst"

# 2) Background drawable - brand gradient (unchanged).
$bg = "D:\codes\streetlore\android\app\src\main\res\drawable\ic_launcher_background.xml"
$bgXml = @'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:pathData="M0,0h108v108h-108z"
        android:fillColor="#0F172A"/>
    <path
        android:pathData="M0,0h108v108h-108z">
        <aapt:attr xmlns:aapt="http://schemas.android.com/aapt" name="android:fillColor">
            <gradient
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108"
                android:type="linear">
                <item android:offset="0.0" android:color="#F59E0B"/>
                <item android:offset="0.5" android:color="#EF4444"/>
                <item android:offset="1.0" android:color="#3B82F6"/>
            </gradient>
        </aapt:attr>
    </path>
</vector>
'@
Set-Content -LiteralPath $bg -Value $bgXml -Encoding UTF8
Write-Host "Background: $bg"

# 3) Adaptive icon XML for Android 8.0+.
$dir = "D:\codes\streetlore\android\app\src\main\res\mipmap-anydpi-v26"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$adaptive = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
'@
Set-Content -LiteralPath (Join-Path $dir 'ic_launcher.xml') -Value $adaptive -Encoding UTF8
Set-Content -LiteralPath (Join-Path $dir 'ic_launcher_round.xml') -Value $adaptive -Encoding UTF8
Write-Host "Adaptive icon XML: $dir"

# 4) Regenerate the legacy mipmap PNGs from the cropped foreground
#    so pre-O launchers see the same design (Android < 8 is < 1% of
#    active devices but kept for completeness).
Add-Type -AssemblyName System.Drawing
$fgFile = "D:\codes\streetlore\android\app\src\main\res\drawable\ic_launcher_foreground.png"
$sizes = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($entry in $sizes.GetEnumerator()) {
    $dirName = $entry.Key
    $side = [int]$entry.Value
    $target = "D:\codes\streetlore\android\app\src\main\res\$dirName\ic_launcher.png"
    Add-Type -AssemblyName System.Drawing
    $outBmp = New-Object System.Drawing.Bitmap $side, $side
    $og = [System.Drawing.Graphics]::FromImage($outBmp)
    $og.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $src = [System.Drawing.Image]::FromFile($fgFile)
    $og.DrawImage($src, 0, 0, $side, $side)
    $src.Dispose()
    $og.Dispose()
    $outBmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $outBmp.Dispose()
    Write-Host "Legacy PNG: $target ($side px)"
}
Write-Host "Done."
