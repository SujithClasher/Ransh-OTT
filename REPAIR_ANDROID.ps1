$ErrorActionPreference = "Stop"

Write-Host "Starting Ransh Android Repair..." -ForegroundColor Cyan

# 1. Backup existing android folder
if (Test-Path "android") {
    Write-Host "Backing up android folder..."
    if (Test-Path "android_old") { Remove-Item "android_old" -Recurse -Force }
    Rename-Item "android" "android_old"
}

# 2. Re-create Android project
Write-Host "Re-creating Android platform files..."
flutter create --platforms=android .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter create failed!"
    exit 1
}

# 3. Restore google-services.json
$gsPath = "android_old\app\google-services.json"
if (Test-Path $gsPath) {
    Write-Host "Restoring google-services.json..."
    Copy-Item $gsPath "android\app\"
} else {
    Write-Warning "google-services.json not found in backup! You may need to download it again from Firebase."
}

# 4. Restore TV Banner image
$bannerSrc = "android_old\app\src\main\res\drawable\tv_banner.png"
if (Test-Path $bannerSrc) {
    Write-Host "Restoring TV Banner..."
    Copy-Item $bannerSrc "android\app\src\main\res\drawable\"
} else {
    # Try to copy from assets if backup fails
    if (Test-Path "assets\images\tv_banner.png") {
        Copy-Item "assets\images\tv_banner.png" "android\app\src\main\res\drawable\tv_banner.png"
    } else {
        Write-Warning "tv_banner.png not found!"
    }
}

# 5. Fix launch_background.xml (The Crash Fix)
Write-Host "Applying Splash Screen Crash Fix..."
$launchXml = @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#1A1A2E"/>
        </shape>
    </item>
</layer-list>
"@

$launchPath = "android\app\src\main\res\drawable\launch_background.xml"
$launchPathV21 = "android\app\src\main\res\drawable-v21\launch_background.xml"
Set-Content -Path $launchPath -Value $launchXml
if (Test-Path $launchPathV21) {
    Set-Content -Path $launchPathV21 -Value $launchXml
}

# 6. Apply AndroidManifest.xml changes (Banner)
Write-Host "Configuring TV Banner in Manifest..."
$manifestPath = "android\app\src\main\AndroidManifest.xml"
$manifestContent = Get-Content $manifestPath -Raw

# Add banner attribute
if ($manifestContent -notmatch 'android:banner') {
    $manifestContent = $manifestContent -replace 'android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/tv_banner"'
}

Set-Content -Path $manifestPath -Value $manifestContent

Write-Host "Repair Complete!" -ForegroundColor Green
Write-Host "Now run: flutter run -apk --debug" -ForegroundColor Yellow
