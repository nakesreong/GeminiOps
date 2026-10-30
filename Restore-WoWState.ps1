<#
.SYNOPSIS
    Restores the complete World of Warcraft (_retail_) WTF configuration, SavedVariables,
    macros, keybindings, ElvUI bundle, and our 4 custom GitHub addons (SpArc, MAWM, MountCollector, GeminiOps).

.DESCRIPTION
    Run this script after reinstalling Windows or World of Warcraft:
      1. Verifies that Wow.exe is closed (so WoW does not overwrite restored SavedVariables).
      2. Creates a safety zip of any existing WTF folder before overwriting.
      3. Restores Backup/WTF/* -> C:\Program Files (x86)\World of Warcraft\_retail_\WTF\
      4. Extracts Backup/ElvUI_Bundle.zip -> Interface\AddOns\
      5. Deploys (or clones from GitHub) SpArc, MAWM, MountCollector, and GeminiOps -> Interface\AddOns\
      6. Checks AddOns_Manifest.json and lists any remaining CurseForge addons to install via CurseForge app.

.PARAMETER WoWRetailPath
    Path to World of Warcraft\_retail_ (defaults to 'C:\Program Files (x86)\World of Warcraft\_retail_').
#>
[CmdletBinding()]
param(
    [string]$WoWRetailPath = "C:\Program Files (x86)\World of Warcraft\_retail_"
)

$ErrorActionPreference = "Stop"
$RepoRoot     = Split-Path -Parent $MyInvocation.MyCommand.Path
$GamesRoot    = Split-Path -Parent $RepoRoot
$BackupRoot   = Join-Path $RepoRoot "Backup"
$BackupWTF    = Join-Path $BackupRoot "WTF"
$TargetWTF    = Join-Path $WoWRetailPath "WTF"
$TargetAddOns = Join-Path $WoWRetailPath "Interface\AddOns"

Write-Host "=== [GeminiOps] World of Warcraft Disaster Recovery & Restore ===" -ForegroundColor Cyan

# 1. Ensure WoW is closed
$wowProc = Get-Process -Name "Wow" -ErrorAction SilentlyContinue
if ($wowProc) {
    throw "World of Warcraft (Wow.exe) is currently running! Please close the game completely before running Restore-WoWState.ps1 so WoW does not overwrite restored SavedVariables on exit."
}

if (-not (Test-Path $BackupWTF)) {
    throw "Backup WTF folder not found at: $BackupWTF"
}

if (-not (Test-Path $WoWRetailPath)) {
    New-Item -ItemType Directory -Path $WoWRetailPath -Force | Out-Null
}
if (-not (Test-Path $TargetAddOns)) {
    New-Item -ItemType Directory -Path $TargetAddOns -Force | Out-Null
}

# 2. Create safety backup of existing WTF if present
if (Test-Path $TargetWTF) {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $safetyZip = Join-Path $WoWRetailPath "WTF_PreRestore_$ts.zip"
    Write-Host "[1/5] Saving safety snapshot of existing WTF -> $safetyZip" -ForegroundColor Yellow
    Compress-Archive -Path $TargetWTF -DestinationPath $safetyZip -CompressionLevel Fast -Force
} else {
    Write-Host "[1/5] No existing WTF folder found; performing clean restore." -ForegroundColor Gray
}

# 3. Restore WTF files
$backupFiles = Get-ChildItem -Path $BackupWTF -Recurse -File
$restoredCount = 0
foreach ($file in $backupFiles) {
    $relPath = $file.FullName.Substring($BackupWTF.Length).TrimStart('\', '/')
    $destPath = Join-Path $TargetWTF $relPath
    $destDir  = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
    $restoredCount++
}
Write-Host "[2/5] Restored $restoredCount WTF files (Config.wtf, SavedVariables, Macros, Keybinds) -> $TargetWTF" -ForegroundColor Green

# 4. Extract ElvUI_Bundle.zip if present
$elvZip = Join-Path $BackupRoot "ElvUI_Bundle.zip"
if (Test-Path $elvZip) {
    Expand-Archive -LiteralPath $elvZip -DestinationPath $TargetAddOns -Force
    Write-Host "[3/5] Extracted ElvUI offline bundle -> $TargetAddOns" -ForegroundColor Green
} else {
    Write-Host "[3/5] ElvUI_Bundle.zip not found in Backup/; skipping ElvUI zip extraction." -ForegroundColor Yellow
}

# 5. Deploy our 4 custom GitHub addons (SpArc, MAWM, MountCollector, GeminiOps)
$customAddons = @(
    @{ Name = "GeminiOps";      Repo = "https://github.com/nakesreong/GeminiOps.git" },
    @{ Name = "SpArc";          Repo = "https://github.com/nakesreong/SpArc.git" },
    @{ Name = "MAWM";           Repo = "https://github.com/nakesreong/MAWM.git" },
    @{ Name = "MountCollector"; Repo = "https://github.com/nakesreong/MountCollector.git" }
)

foreach ($addon in $customAddons) {
    $name = $addon.Name
    $localSrc = if ($name -eq "GeminiOps") { $RepoRoot } else { Join-Path $GamesRoot $name }
    if (-not (Test-Path $localSrc)) {
        Write-Host "  Cloning $name from $($addon.Repo) -> $localSrc ..." -ForegroundColor Cyan
        git clone $addon.Repo $localSrc
    }
    $destAddon = Join-Path $TargetAddOns $name
    if (-not (Test-Path $destAddon)) {
        New-Item -ItemType Directory -Path $destAddon -Force | Out-Null
    }
    # Copy runtime addon files (excluding .git, Backup, and .bak files)
    Get-ChildItem -Path $localSrc -Force | Where-Object {
        $_.Name -notin @('.git', '.github', 'Backup', '.gitignore') -and $_.Extension -notin @('.bak', '.ps1')
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $destAddon -Recurse -Force
    }
    Write-Host "  Deployed custom addon: $name -> $destAddon" -ForegroundColor Green
}
Write-Host "[4/5] Deployed all 4 custom addons (GeminiOps, SpArc, MAWM, MountCollector)." -ForegroundColor Green

# 6. Check AddOns_Manifest.json for missing third-party CurseForge/Wago addons
$manifestPath = Join-Path $BackupRoot "AddOns_Manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $missing = @()
    foreach ($entry in $manifest) {
        $checkPath = Join-Path $TargetAddOns $entry.Name
        if (-not (Test-Path $checkPath)) {
            $missing += $entry
        }
    }
    if ($missing.Count -eq 0) {
        Write-Host "[5/5] All $($manifest.Count) addons from AddOns_Manifest.json are present in Interface\AddOns!" -ForegroundColor Green
    } else {
        Write-Host "[5/5] $($missing.Count) third-party addons are not yet installed in Interface\AddOns:" -ForegroundColor Yellow
        $missing | ForEach-Object {
            Write-Host ("  - {0} ({1})" -f $_.Name, $_.Version) -ForegroundColor Gray
        }
        Write-Host "Tip: Open CurseForge App -> World of Warcraft to reinstall third-party addons; their profiles & settings are ALREADY restored in WTF\SavedVariables!" -ForegroundColor Cyan
    }
}

Write-Host "=== Restore Complete! You can now launch World of Warcraft. ===" -ForegroundColor Cyan
