$ErrorActionPreference = "Stop"

$workspaceRoot = "c:\Users\Deepak Chheda\OneDrive\Desktop\stock_inventory_system\Stock_Inventory_managment_system"
$tempSrc = "C:\Users\Deepak Chheda\flutter_build_temp_src"

Write-Host "==========================================="
Write-Host "InventoryPro - OneDrive Safe Build Script"
Write-Host "==========================================="

# 1. Clean up old temp directory if it exists
if (Test-Path $tempSrc) {
    Write-Host "[1/5] Removing old temporary build directory..."
    Remove-Item -Recurse -Force $tempSrc
}

# 2. Create the temp directory
Write-Host "[2/5] Creating temporary build directory at $tempSrc..."
New-Item -ItemType Directory -Path $tempSrc | Out-Null

# 3. Copy source files recursively excluding build caches to speed up copy
Write-Host "[3/5] Mirroring Flutter project files to temporary build directory..."
robocopy "$workspaceRoot\inventory_system\flutter_app" "$tempSrc" /E /XD .dart_tool build .gradle .idea windows\flutter\ephemeral /R:1 /W:1
if ($LASTEXITCODE -ge 8) {
    throw "Robocopy failed to copy project files with exit code $LASTEXITCODE"
}

# 4. Set PATH to include Flutter
$env:Path = "C:\Users\Deepak Chheda\Downloads\flutter_sdk\flutter\bin;" + $env:Path

# 5. Initialize the Distribution folder in workspace and clear old outputs
Set-Location -Path $workspaceRoot
if (!(Test-Path "Distribution")) { New-Item -ItemType Directory -Path "Distribution" | Out-Null }
if (!(Test-Path "Distribution\Web")) { New-Item -ItemType Directory -Path "Distribution\Web" | Out-Null }
if (!(Test-Path "Distribution\Mobile")) { New-Item -ItemType Directory -Path "Distribution\Mobile" | Out-Null }
if (!(Test-Path "Distribution\Windows")) { New-Item -ItemType Directory -Path "Distribution\Windows" | Out-Null }

Remove-Item -Recurse -Force "Distribution\Web\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "Distribution\Mobile\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "Distribution\Windows\*" -ErrorAction SilentlyContinue

# 6. Run builds in the temp directory and copy outputs immediately after compilation
Set-Location -Path $tempSrc

Write-Host "[4/5] Running Flutter Web build..."
flutter build web
Write-Host "[5/5] Copying Web build to Distribution/Web..."
Copy-Item -Path "$tempSrc\build\web\*" -Destination "$workspaceRoot\Distribution\Web" -Recurse -Force

Write-Host "[4/5] Running Flutter Android APK build..."
flutter clean
flutter build apk --release
Write-Host "[5/5] Copying Android APK to Distribution/Mobile..."
Copy-Item -Path "$tempSrc\build\app\outputs\flutter-apk\app-release.apk" -Destination "$workspaceRoot\Distribution\Mobile\InventoryPro.apk" -Force

Write-Host "[4/5] Running Flutter Windows release build..."
flutter clean
flutter build windows --release
Write-Host "[5/5] Copying Windows build to Distribution/Windows..."
Copy-Item -Path "$tempSrc\build\windows\x64\runner\Release\*" -Destination "$workspaceRoot\Distribution\Windows" -Recurse -Force

# 7. Clean up temp folder
Set-Location -Path $workspaceRoot
Write-Host "[Cleanup] Cleaning up temporary build files..."
Remove-Item -Recurse -Force $tempSrc

Write-Host "==========================================="
Write-Host "BUILD SUCCESSFUL! Built artifacts saved to Distribution/"
Write-Host "==========================================="
