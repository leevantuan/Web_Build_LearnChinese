# ============================================================
# build.ps1 - Build FE & BE vao Web_Build
# Chay: powershell -ExecutionPolicy Bypass -File build.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $PSScriptRoot

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  LearningChinese - Build for Docker" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# -- 1. Build Frontend (Angular) --
Write-Host "" -ForegroundColor Yellow
Write-Host "[1/2] Building Frontend (Angular)..." -ForegroundColor Yellow
$feSrc = "$ROOT\LearningChinese_FE"
$feBuild = "$ROOT\Web_Build\frontend\build"

if (Test-Path $feBuild) { Remove-Item -Recurse -Force $feBuild }

Push-Location $feSrc
npx ng build --configuration=production
Pop-Location

$feDistBrowser = "$feSrc\dist\LearningChinese_FE\browser"
if (Test-Path $feDistBrowser) {
    Copy-Item -Recurse $feDistBrowser $feBuild
} else {
    Copy-Item -Recurse "$feSrc\dist\LearningChinese_FE" $feBuild
}
Write-Host "  => FE build ok: $feBuild" -ForegroundColor Green

# -- 2. Build Backend (.NET) --
Write-Host "" -ForegroundColor Yellow
Write-Host "[2/2] Building Backend (.NET 9)..." -ForegroundColor Yellow
$beSrc = "$ROOT\LearningChinese_BE"
$beBuild = "$ROOT\Web_Build\backend\build"

if (Test-Path $beBuild) { Remove-Item -Recurse -Force $beBuild }

Push-Location $beSrc
dotnet publish .\src\LearningChinese.API\LearningChinese.API.csproj `
    -c Release `
    -o "$beBuild" `
    -p:EnvironmentName=Production
Pop-Location

Write-Host "  => BE build ok: $beBuild" -ForegroundColor Green

# -- Done --
Write-Host "" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build completed!" -ForegroundColor Green
Write-Host "  Next: docker-compose up -d --build" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
