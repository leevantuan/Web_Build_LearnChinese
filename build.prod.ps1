# ============================================================
# build.prod.ps1 - Build FE & BE cho Production (Ubuntu Docker)
# Chay: powershell -ExecutionPolicy Bypass -File build.prod.ps1
# ============================================================
# - Build FE voi configuration=production (environment.ts)
# - Build BE voi EnvironmentName=Docker (dung appsettings.Docker.json)
# - Kiem tra output truoc khi bat dau
# - Hien thi huong dan upload len server
# ============================================================

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $PSScriptRoot

Write-Host "" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  LearningChinese - Build for PRODUCTION" -ForegroundColor Cyan
Write-Host "  Target: Ubuntu Docker (learnzh.website)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Pre-check: dotnet & node ──
Write-Host "[Pre] Kiem tra tools..." -ForegroundColor Gray
try { $null = dotnet --version } catch { Write-Error "Chua cai dotnet SDK!"; exit 1 }
try { $null = node --version }   catch { Write-Error "Chua cai Node.js!"; exit 1 }
try { $null = npx --version }    catch { Write-Error "Chua cai npx!"; exit 1 }
Write-Host "  => dotnet $(dotnet --version) | node $(node --version)" -ForegroundColor Gray

# ── Tinh thoi gian ──
$startTime = Get-Date

# == 1. Build Frontend (Angular) ==
Write-Host "" -ForegroundColor Yellow
Write-Host "[1/3] Building Frontend (Angular - production)..." -ForegroundColor Yellow
$feSrc   = "$ROOT\LearningChinese_FE"
$feBuild = "$ROOT\Web_Build\frontend\build"

if (Test-Path $feBuild) { Remove-Item -Recurse -Force $feBuild }

Push-Location $feSrc
npx ng build --configuration=production
Pop-Location

# Angular 18+ output vao dist/<project>/browser
$feDistBrowser = "$feSrc\dist\LearningChinese_FE\browser"
if (Test-Path $feDistBrowser) {
    Copy-Item -Recurse $feDistBrowser $feBuild
} else {
    Copy-Item -Recurse "$feSrc\dist\LearningChinese_FE" $feBuild
}

# Kiem tra ket qua
$feFiles = (Get-ChildItem -Recurse $feBuild -File).Count
Write-Host "  => FE build OK: $feBuild ($feFiles files)" -ForegroundColor Green

# == 2. Build Backend (.NET 9) ==
Write-Host "" -ForegroundColor Yellow
Write-Host "[2/3] Building Backend (.NET 9 - Release)..." -ForegroundColor Yellow
$beSrc   = "$ROOT\LearningChinese_BE"
$beBuild = "$ROOT\Web_Build\backend\build"

if (Test-Path $beBuild) { Remove-Item -Recurse -Force $beBuild }

Push-Location $beSrc
dotnet publish .\src\LearningChinese.API\LearningChinese.API.csproj `
    -c Release `
    -o "$beBuild" `
    -p:EnvironmentName=Docker
Pop-Location

# Kiem tra ket qua
$beFiles = (Get-ChildItem -Recurse $beBuild -File).Count
$hasDll  = Test-Path "$beBuild\LearningChinese.API.dll"
if (-not $hasDll) { Write-Error "KHONG TIM THAY LearningChinese.API.dll!"; exit 1 }
Write-Host "  => BE build OK: $beBuild ($beFiles files)" -ForegroundColor Green

# == 3. Kiem tra cac file config can thiet ==
Write-Host "" -ForegroundColor Yellow
Write-Host "[3/3] Kiem tra cau truc deploy..." -ForegroundColor Yellow

$checkFiles = @(
    "$ROOT\Web_Build\docker-compose.prod.yaml",
    "$ROOT\Web_Build\.env.prod",
    "$ROOT\Web_Build\deploy.sh",
    "$ROOT\Web_Build\frontend\Dockerfile.prod",
    "$ROOT\Web_Build\frontend\nginx.prod.conf",
    "$ROOT\Web_Build\backend\Dockerfile"
)

$allOk = $true
foreach ($f in $checkFiles) {
    $exists = Test-Path $f
    $icon   = if ($exists) { "[OK]" } else { "[!!]" }
    $color  = if ($exists) { "Green" } else { "Red" }
    Write-Host "  $icon $(Split-Path -Leaf $f)" -ForegroundColor $color
    if (-not $exists) { $allOk = $false }
}

if (-not $allOk) {
    Write-Host "" -ForegroundColor Red
    Write-Warning "Mot so file config/source bi thieu! Kiem tra lai truoc khi deploy."
}

# ── Kiem tra appsettings.Docker.json da duoc include ──
$dockerConfig = "$beBuild\appsettings.Docker.json"
if (Test-Path $dockerConfig) {
    Write-Host "  [OK] appsettings.Docker.json da co trong build output" -ForegroundColor Green
} else {
    Write-Host "  [!!] appsettings.Docker.json KHONG CO trong build output!" -ForegroundColor Red
    Write-Host "       Backend se dung gia tri mac dinh - can kiem tra lai" -ForegroundColor Yellow
}

# ── Tinh tong thoi gian ──
$elapsed = (Get-Date) - $startTime

# == Done ==
Write-Host "" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PRODUCTION BUILD THANH CONG!" -ForegroundColor Green
Write-Host "  Thoi gian: $([math]::Round($elapsed.TotalSeconds, 1))s" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Cau truc Web_Build:" -ForegroundColor White
Write-Host '    frontend/build/  - Angular production output' -ForegroundColor Gray
Write-Host '    backend/build/   - .NET publish output' -ForegroundColor Gray
Write-Host ""
Write-Host "  Buoc tiep theo:" -ForegroundColor White
Write-Host "  1. Upload Web_Build len server:" -ForegroundColor Gray
Write-Host "     scp -r Web_Build/ root@103.149.87.43:/opt/learnchinese/" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. SSH vao server va chay:" -ForegroundColor Gray
Write-Host "     cd /opt/learnchinese/Web_Build" -ForegroundColor DarkGray
Write-Host '     chmod +x deploy.sh' -ForegroundColor DarkGray
Write-Host '     sudo ./deploy.sh' -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Hoac chi update FE/BE:" -ForegroundColor Gray
Write-Host "     docker compose -f docker-compose.prod.yaml up -d --build frontend backend" -ForegroundColor DarkGray
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
