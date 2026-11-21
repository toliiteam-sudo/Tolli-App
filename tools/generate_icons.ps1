Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Admin\.gemini\antigravity\brain\d6c37ba5-de18-4311-8b52-3e1df259392e\.user_uploaded\media_1795256592245_1754102b.png"
if (-not (Test-Path $src)) {
    Write-Error "Source image not found: $src"
    exit 1
}

# Also save master app logo to assets/images
if (-not (Test-Path "assets/images")) {
    New-Item -ItemType Directory -Path "assets/images" -Force | Out-Null
}
Copy-Item $src "assets/images/app_logo.png" -Force

$img = [System.Drawing.Image]::FromFile($src)

function Resize-Image($image, $width, $height, $outPath) {
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $destImage = New-Object System.Drawing.Bitmap($width, $height)
    $destImage.SetResolution($image.HorizontalResolution, $image.VerticalResolution)
    $graphics = [System.Drawing.Graphics]::FromImage($destImage)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($image, $destRect, 0, 0, $image.Width, $image.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $destImage.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $destImage.Dispose()
}

# Android mipmap target dimensions
$androidTargets = @(
    @{ Path = "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"; Size = 48 },
    @{ Path = "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"; Size = 72 },
    @{ Path = "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"; Size = 96 },
    @{ Path = "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"; Size = 144 },
    @{ Path = "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"; Size = 192 }
)

foreach ($t in $androidTargets) {
    $dir = Split-Path $t.Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Resize-Image $img $t.Size $t.Size $t.Path
    Write-Output "Generated Android: $($t.Path) ($($t.Size)x$($t.Size))"
}

# iOS AppIcon target dimensions
if (Test-Path "ios/Runner/Assets.xcassets/AppIcon.appiconset") {
    $iosTargets = @(
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"; Size = 1024 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"; Size = 20 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"; Size = 40 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"; Size = 60 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"; Size = 29 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"; Size = 58 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"; Size = 87 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"; Size = 40 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"; Size = 80 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"; Size = 120 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"; Size = 120 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"; Size = 180 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"; Size = 76 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"; Size = 152 },
        @{ Path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"; Size = 167 }
    )
    foreach ($t in $iosTargets) {
        Resize-Image $img $t.Size $t.Size $t.Path
        Write-Output "Generated iOS: $($t.Path) ($($t.Size)x$($t.Size))"
    }
}

$img.Dispose()
Write-Output "ALL_APP_ICONS_GENERATED_SUCCESSFULLY"

