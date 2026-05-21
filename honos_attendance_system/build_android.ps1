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

Write-Host "6/6 Building the Android APK..." -ForegroundColor Cyan
flutter build apk --debug

Write-Host "`n✅ SUCCESS! Your APK has been built." -ForegroundColor Green
Write-Host "You can find it here: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Yellow
Write-Host "Connect your phone with a USB cable, copy this file over, and install it to test the real AI!" -ForegroundColor White
