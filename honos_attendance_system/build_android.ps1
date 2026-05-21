$ErrorActionPreference = "Stop"

$SdkPath = "C:\AndroidSDK"
$ZipPath = "cmdline-tools.zip"
$Url = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

Write-Host "1/6 Downloading Android Command Line Tools..." -ForegroundColor Cyan
if (-not (Test-Path $SdkPath)) {
    New-Item -ItemType Directory -Force -Path $SdkPath | Out-Null
}

if (-not (Test-Path "$SdkPath\cmdline-tools\latest\bin\sdkmanager.bat")) {
    if (-not (Test-Path $ZipPath)) {
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath
    }
    Write-Host "2/6 Extracting tools..." -ForegroundColor Cyan
    Expand-Archive -Path $ZipPath -DestinationPath $SdkPath -Force
    # It extracts to $SdkPath\cmdline-tools. We need $SdkPath\cmdline-tools\latest
    Rename-Item "$SdkPath\cmdline-tools" "latest"
    New-Item -ItemType Directory -Force -Path "$SdkPath\cmdline-tools" | Out-Null
    Move-Item "$SdkPath\latest" "$SdkPath\cmdline-tools\"
} else {
    Write-Host "2/6 Tools already extracted, skipping..." -ForegroundColor Cyan
}

Write-Host "3/6 Installing Android Platform & Build Tools (this may take a minute)..." -ForegroundColor Cyan
$SdkManager = "$SdkPath\cmdline-tools\latest\bin\sdkmanager.bat"
& $SdkManager "platform-tools" "platforms;android-34" "build-tools;34.0.0" --sdk_root=$SdkPath

Write-Host "4/6 Accepting Android Licenses..." -ForegroundColor Cyan
$yesStr = "y`n" * 20
$yesStr | & $SdkManager --licenses --sdk_root=$SdkPath

Write-Host "5/6 Configuring Flutter to use this SDK..." -ForegroundColor Cyan
flutter config --android-sdk $SdkPath | Out-Null

Write-Host "6/6 Select Android Build Type:" -ForegroundColor Cyan
Write-Host "  [1] Split-ABI Release APKs (RECOMMENDED: Generates separate ~35MB APKs for each architecture)" -ForegroundColor Green
Write-Host "  [2] Android App Bundle (.aab) (Production release format for Google Play Store)" -ForegroundColor Gray
Write-Host "  [3] Fat Release APK (Single ~114MB APK containing all architectures)" -ForegroundColor Gray
Write-Host "  [4] Debug APK (Unoptimized development build with VM & hot reload tools, ~120MB)" -ForegroundColor Gray

$choice = Read-Host "Enter your choice (1-4, default is 1)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

switch ($choice) {
    "1" {
        Write-Host "`nBuilding Split-ABI Release APKs..." -ForegroundColor Cyan
        flutter build apk --release --split-per-abi
        Write-Host "`n✅ SUCCESS! Split APKs have been built successfully." -ForegroundColor Green
        Write-Host "You can find the optimized APKs here: build\app\outputs\flutter-apk\" -ForegroundColor Yellow
        Write-Host "  - For 64-bit phones (most modern devices): app-arm64-v8a-release.apk (approx 35-40MB)" -ForegroundColor White
        Write-Host "  - For 32-bit phones (older devices): app-armeabi-v7a-release.apk (approx 30-35MB)" -ForegroundColor White
        Write-Host "  - For emulators/PC: app-x86_64-release.apk (approx 40MB)" -ForegroundColor White
        Write-Host "Connect your phone, copy the correct APK, and install a lightweight build with 100% performance!" -ForegroundColor Gray
    }
    "2" {
        Write-Host "`nBuilding Android App Bundle (.aab)..." -ForegroundColor Cyan
        flutter build appbundle --release
        Write-Host "`n✅ SUCCESS! App Bundle (.aab) has been built successfully." -ForegroundColor Green
        Write-Host "You can find it here: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
        Write-Host "Upload this file to the Google Play Console to distribute the smallest possible device-tailored APKs to users." -ForegroundColor White
    }
    "3" {
        Write-Host "`nBuilding Fat Release APK..." -ForegroundColor Cyan
        flutter build apk --release
        Write-Host "`n✅ SUCCESS! Fat Release APK has been built successfully." -ForegroundColor Green
        Write-Host "You can find it here: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
        Write-Host "Note: This single file contains all architectures, so it remains ~114MB." -ForegroundColor Gray
    }
    "4" {
        Write-Host "`nBuilding Debug APK..." -ForegroundColor Cyan
        flutter build apk --debug
        Write-Host "`n✅ SUCCESS! Debug APK has been built." -ForegroundColor Green
        Write-Host "You can find it here: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Yellow
    }
    default {
        Write-Error "Invalid choice selected."
    }
}

