# install.ps1 — One-line installer for framework-llm on Windows
#
# Usage:
#   irm https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.ps1 | iex
#
# Este script descarga los binarios desde el repo PÚBLICO de releases
# (TP202610017/framework-llm-releases), que aloja solo artefactos
# compilados. El código fuente del framework vive en un repo separado
# y privado — NO es accesible desde aquí ni queda expuesto al usuario.
#
# Lo que hace:
#   1. Detecta arquitectura de CPU (amd64 / arm64).
#   2. Resuelve la última release vía GitHub API.
#   3. Descarga el .zip que matchea con tu OS+arch.
#   4. Extrae isw.exe a %LOCALAPPDATA%\Programs\isw\.
#   5. Agrega esa carpeta al User PATH (idempotente).
#   6. Verifica `isw version`.

$ErrorActionPreference = "Stop"

# ─── Config ──────────────────────────────────────────────────────────
# Repo PÚBLICO de releases. El código fuente está en otro repo
# privado, fuera del alcance de este script.
$Repo       = "TP202610017/framework-llm-releases"
$BinaryName = "isw.exe"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\isw"

# ─── Helpers ─────────────────────────────────────────────────────────
function Write-Step($msg)    { Write-Host "▶  $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "✓  $msg" -ForegroundColor Green }
function Write-WarnLine($msg) { Write-Host "⚠  $msg" -ForegroundColor Yellow }
function Die($msg) {
    Write-Host "✗  $msg" -ForegroundColor Red
    exit 1
}

# ─── 1. Architecture detection ───────────────────────────────────────
Write-Step "Detecting architecture"
$Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64"  { "x86_64" }
    "ARM64"  { "arm64" }
    default  { Die "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}
Write-Ok "arch=$Arch"

# ─── 2. Resolve latest release ───────────────────────────────────────
Write-Step "Fetching latest release info"
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
                                 -Headers @{ "User-Agent" = "isw-installer" }
}
catch {
    Die "Could not reach GitHub API: $_"
}
$Version = $release.tag_name
Write-Ok "latest=$Version"

# ─── 3. Find the right asset ─────────────────────────────────────────
$AssetName = "isw-framework-llm_${Version}_windows_${Arch}.zip" -replace "^v", ""
$Asset = $release.assets | Where-Object { $_.name -like "*windows*$Arch*" -and $_.name -like "*.zip" } | Select-Object -First 1

if (-not $Asset) {
    Die "No release asset matches windows/$Arch in $Version"
}
Write-Ok "asset=$($Asset.name)"

# ─── 4. Download + extract ───────────────────────────────────────────
$Tmp = New-TemporaryFile
Remove-Item $Tmp; New-Item -ItemType Directory -Path $Tmp | Out-Null
$ZipPath = Join-Path $Tmp $Asset.name

Write-Step "Downloading $($Asset.name)"
Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ZipPath -UseBasicParsing

Write-Step "Extracting to $InstallDir"
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Expand-Archive -Path $ZipPath -DestinationPath $Tmp -Force

# El zip de goreleaser deja el binario en la raíz del archivo.
$ExtractedExe = Get-ChildItem -Path $Tmp -Recurse -Filter $BinaryName | Select-Object -First 1
if (-not $ExtractedExe) {
    Die "Could not find $BinaryName inside the archive"
}
Copy-Item -Path $ExtractedExe.FullName -Destination (Join-Path $InstallDir $BinaryName) -Force
Remove-Item -Recurse -Force $Tmp
Write-Ok "binary placed at $(Join-Path $InstallDir $BinaryName)"

# ─── 5. Add to PATH (User scope) ─────────────────────────────────────
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -split ";" -notcontains $InstallDir) {
    Write-Step "Adding $InstallDir to User PATH"
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
    Write-Ok "PATH updated (open a new terminal to pick it up)"
}
else {
    Write-Ok "PATH already contains $InstallDir"
}

# ─── 6. Verify ───────────────────────────────────────────────────────
Write-Step "Verifying installation"
try {
    $verOut = & (Join-Path $InstallDir $BinaryName) version 2>&1
    Write-Ok "isw is installed:"
    Write-Host $verOut -ForegroundColor Gray
}
catch {
    Write-WarnLine "Installed, but `isw version` failed: $_"
}

Write-Host ""
Write-Host "✦ Done. Open a new terminal and run:" -ForegroundColor Magenta
Write-Host "    isw" -ForegroundColor White
Write-Host ""
