$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# 1) Build a foreground PNG sized 432x432 (108dp at xxxhdpi) from the
#    1024x1024 brand logo, with a tiny safe-zone padding so adaptive
#    icon launchers (Samsung/OnePlus/Pixel) keep the logo readable.
$src = "D:\codes\streetlore\assets\logo\streetlore_logo.png"
$dst = "D:\codes\streetlore\android\app\src\main\res\drawable\ic_launcher_foreground.png"

# We use the existing 1024x1024 logo as the foreground. Android scales
# it to fit the adaptive icon's foreground slot. No extra padding: the
# logo already has its own rounded-square frame that fills the bounds.
Copy-Item -LiteralPath $src -Destination $dst -Force
Write-Host "Foreground: $dst"

# 2) Build a background drawable - gradient that matches the brand
$bg = "D:\codes\streetlore\android\app\src\main\res\drawable\ic_launcher_background.xml"
$bgXml = @"
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:pathData="M0,0h108v108h-108z"
        android:fillColor="#F59E0B"/>
    <path
        android:pathData="M0,0h108v108h-108z"
        android:fillAlpha="0.35">
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
"@
Set-Content -LiteralPath $bg -Value $bgXml -Encoding UTF8
Write-Host "Background: $bg"

# 3) Adaptive icon definition (Android 8.0+)
$dir = "D:\codes\streetlore\android\app\src\main\res\mipmap-anydpi-v26"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$adaptive = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
"@
Set-Content -LiteralPath (Join-Path $dir 'ic_launcher.xml') -Value $adaptive -Encoding UTF8
Set-Content -LiteralPath (Join-Path $dir 'ic_launcher_round.xml') -Value $adaptive -Encoding UTF8
Write-Host "Adaptive icon XML: $dir"

Write-Host "Done."
