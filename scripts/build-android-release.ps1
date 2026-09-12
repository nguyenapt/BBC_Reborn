# Build Android App Bundle with GMA Next-Gen SDK enabled.
# Usage: pwsh ./scripts/build-android-release.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Building AAB with USE_NEXT_GEN_SDK=true ..."
flutter build appbundle --release --dart-define=USE_NEXT_GEN_SDK=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building APK with USE_NEXT_GEN_SDK=true ..."
flutter build apk --release --dart-define=USE_NEXT_GEN_SDK=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done. Outputs under build/app/outputs/"
