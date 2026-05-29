$ErrorActionPreference = "Stop"
$FLUTTER_ZIP = "$env:USERPROFILE\Downloads\flutter_windows.zip"
$FLUTTER_DIR = "$env:USERPROFILE\Downloads\flutter_sdk"

Write-Host "1. Downloading Flutter SDK..."
if (-not (Test-Path $FLUTTER_ZIP)) {
    curl.exe -L -o $FLUTTER_ZIP "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.2-stable.zip"
} else {
    Write-Host "Flutter zip already exists, skipping download."
}

Write-Host "2. Extracting Flutter SDK..."
if (-not (Test-Path $FLUTTER_DIR)) {
    mkdir $FLUTTER_DIR
    tar.exe -xf $FLUTTER_ZIP -C $FLUTTER_DIR
} else {
    Write-Host "Flutter directory already exists, skipping extraction."
}

Write-Host "3. Adding Flutter to PATH..."
$env:Path = "$FLUTTER_DIR\flutter\bin;" + $env:Path

Write-Host "4. Building Flutter Web App..."
cd "c:\Users\Deepak Chheda\OneDrive\Desktop\stock_inventory_system\Stock_Inventory_managment_system\inventory_system\flutter_app"
flutter build web --dart-define=API_BASE_URL=http://localhost:8000

Write-Host "5. Starting Web Server on Port 8080..."
cd build\web
python -m http.server 8080
