<#
.SYNOPSIS
    Snapshots the complete World of Warcraft (_retail_) configuration, SavedVariables,
    macros, keybindings, ElvUI bundle, and AddOns manifest into the GeminiOps Git repository.

.DESCRIPTION
    Backs up:
      1. WTF/Config.wtf (graphics, D3D12, 3440x1440 ultrawide, audio, global CVars)
      2. WTF/Account/<Account>/ (account macros-cache.txt, bindings-cache.wtf, edit-mode, config-cache)
      3. WTF/Account/<Account>/SavedVariables/*.lua (all 57+ addon databases & profiles: ElvUI, Plater, SpArc, Bartender4, Details, MAWM, etc.)
      4. WTF/Account/<Account>/<Realm>/<Character>/ (all per-character macros, keybinds, chat windows, AddOns.txt, and ElvCharacterDB)
      5. Backup/AddOns_Manifest.json (full inventory of installed Interface/AddOns with versions & CurseForge/Wago IDs)
      6. Backup/ElvUI_Bundle.zip (optional offline bundle of ElvUI + ElvUI_Options + ElvUI_Libraries)

.PARAMETER WoWRetailPath
    Path to World of Warcraft\_retail_ (defaults to 'C:\Program Files (x86)\World of Warcraft\_retail_').

.PARAMETER IncludeElvUIBundle
    Also pack ElvUI, ElvUI_Options, and ElvUI_Libraries into Backup\ElvUI_Bundle.zip.

.PARAMETER CommitAndPush
    Automatically git add, commit, and push the updated backup to GitHub.
#>
[CmdletBinding()]
param(
    [string]$WoWRetailPath = "C:\Program Files (x86)\World of Warcraft\_retail_",
    [switch]$IncludeElvUIBundle = $true,
    [switch]$CommitAndPush = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupRoot = Join-Path $RepoRoot "Backup"
$BackupWTF  = Join-Path $BackupRoot "WTF"
$SourceWTF  = Join-Path $WoWRetailPath "WTF"
$SourceAddOns = Join-Path $WoWRetailPath "Interface\AddOns"

Write-Host "=== [GeminiOps] World of Warcraft State Backup ===" -ForegroundColor Cyan

if (-not (Test-Path $SourceWTF)) {
    throw "WTF directory not found at: $SourceWTF"
}

$wowProc = Get-Process -Name "Wow" -ErrorAction SilentlyContinue
if ($wowProc) {
    Write-Warning "World of Warcraft (Wow.exe) is currently running! Note that in-memory changes made during the current session are only flushed to disk on /reload or game exit."
}

# 1. Clean & copy WTF (excluding .bak and .old files)
if (Test-Path $BackupWTF) {
    Remove-Item -Path $BackupWTF -Recurse -Force
}
New-Item -ItemType Directory -Path $BackupWTF -Force | Out-Null

$wtfFiles = Get-ChildItem -Path $SourceWTF -Recurse -File | Where-Object {
    $_.Extension -notin @('.bak', '.old', '.tmp') -and $_.Name -notlike '*.bak' -and $_.Name -notlike '*.old'
}

$copiedCount = 0
$totalBytes  = 0
foreach ($file in $wtfFiles) {
    $relPath = $file.FullName.Substring($SourceWTF.Length).TrimStart('\', '/')
    $destPath = Join-Path $BackupWTF $relPath
    $destDir  = Split-Path -Parent $destPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
    $copiedCount++
    $totalBytes += $file.Length
}

$totalMB = [math]::Round($totalBytes / 1MB, 2)
Write-Host "[1/3] Backed up $copiedCount WTF files ($totalMB MB) -> $BackupWTF" -ForegroundColor Green

# 2. Generate AddOns_Manifest.json from Interface\AddOns
if (Test-Path $SourceAddOns) {
    $manifest = [System.Collections.Generic.List[object]]::new()
    $addonDirs = Get-ChildItem -Path $SourceAddOns -Directory | Sort-Object Name
    foreach ($dir in $addonDirs) {
        $tocFile = Get-ChildItem -Path $dir.FullName -Filter "*.toc" -File | Select-Object -First 1
        $title = $dir.Name
        $version = ""
        $author = ""
        $curseId = ""
        $wagoId = ""
        $tukuiId = ""
        if ($tocFile) {
            $lines = Get-Content -LiteralPath $tocFile.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match '^##\s*Title:\s*(.+)$') { $title = $Matches[1].Trim() }
                elseif ($line -match '^##\s*Version:\s*(.+)$') { $version = $Matches[1].Trim() }
                elseif ($line -match '^##\s*Author:\s*(.+)$') { $author = $Matches[1].Trim() }
                elseif ($line -match '^##\s*X-Curse-Project-ID:\s*(.+)$') { $curseId = $Matches[1].Trim() }
                elseif ($line -match '^##\s*X-Wago-ID:\s*(.+)$') { $wagoId = $Matches[1].Trim() }
                elseif ($line -match '^##\s*X-Tukui-ProjectID:\s*(.+)$') { $tukuiId = $Matches[1].Trim() }
            }
        }
        $isCustomGit = $dir.Name -in @("SpArc", "MAWM", "MountCollector", "BeastCollector", "GeminiOps")
        $manifest.Add([ordered]@{
            Name        = $dir.Name
            Title       = $title
            Version     = $version
            Author      = $author
            CurseID     = $curseId
            WagoID      = $wagoId
            TukuiID     = $tukuiId
            IsCustomGit = $isCustomGit
            GitRepo     = if ($isCustomGit) { "https://github.com/nakesreong/$($dir.Name).git" } else { "" }
        })
    }
    $manifestPath = Join-Path $BackupRoot "AddOns_Manifest.json"
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Host "[2/3] Saved AddOns manifest ($($manifest.Count) addons) -> $manifestPath" -ForegroundColor Green
}

# 3. Bundle ElvUI (not on CurseForge) into Backup\ElvUI_Bundle.zip
if ($IncludeElvUIBundle -and (Test-Path $SourceAddOns)) {
    $elvDirs = @("ElvUI", "ElvUI_Options", "ElvUI_Libraries") | ForEach-Object {
        Join-Path $SourceAddOns $_
    } | Where-Object { Test-Path $_ }

    if ($elvDirs.Count -gt 0) {
        $zipPath = Join-Path $BackupRoot "ElvUI_Bundle.zip"
        if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        Compress-Archive -Path $elvDirs -DestinationPath $zipPath -CompressionLevel Optimal -Force
        $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-Host "[3/3] Packed ElvUI offline bundle ($zipMB MB) -> $zipPath" -ForegroundColor Green
    }
}

# Also sync GeminiOps addon files into live Interface\AddOns\GeminiOps
$liveGeminiOps = Join-Path $SourceAddOns "GeminiOps"
if (-not (Test-Path $liveGeminiOps)) {
    New-Item -ItemType Directory -Path $liveGeminiOps -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $RepoRoot "Core.lua") -Destination (Join-Path $liveGeminiOps "Core.lua") -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "GeminiOps.toc") -Destination (Join-Path $liveGeminiOps "GeminiOps.toc") -Force

if ($CommitAndPush) {
    Push-Location $RepoRoot
    try {
        git add .
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
        git commit -m "backup(wtf): automated WoW WTF, SavedVariables & ElvUI snapshot ($ts)"
        git push origin main
        Write-Host "Successfully committed and pushed backup to GitHub!" -ForegroundColor Cyan
    } finally {
        Pop-Location
    }
}

Write-Host "=== Backup Complete! ===" -ForegroundColor Cyan
