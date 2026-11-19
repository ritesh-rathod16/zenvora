# Zenvora Production Keystore Generator
$KeystorePath = "android/upload-keystore.jks"

if (Test-Path $KeystorePath) {
    Write-Host "Keystore already exists at $KeystorePath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Generating Android Upload Keystore for Zenvora..." -ForegroundColor Green
keytool -genkey -v -keystore $KeystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload

Write-Host "Keystore generated at $KeystorePath." -ForegroundColor Green
Write-Host "Remember to configure android/key.properties based on android/key.properties.example." -ForegroundColor Cyan
