param([ValidateSet('Install','Collect','Uninstall','Update')][string]$Action='Install')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$statePath=Join-Path $PSScriptRoot 'InstalledMerge.json'
function Hash([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
if ($Action -eq 'Install') {
    if (Test-Path -LiteralPath $statePath) { throw 'An installation record exists. Run Uninstall-Mod.cmd before reinstalling.' }
    $paks=(Read-Host 'Paste the full path to Game\Content\Paks').Trim().Trim('"')
    $paks=(Resolve-Path -LiteralPath $paks).Path
    $utoc=Join-Path $paks 'pakchunk0-Windows.utoc'
    if (!(Test-Path -LiteralPath $utoc) -or (Hash $utoc) -ne '7cb150a5f59b78fe53785eb69001af01d63593560fdd2d8063adf3481fee2ab4') { throw 'The archive differs from the supplied GOG 1.0.2.1 build. Nothing was installed.' }
    $game=Split-Path -Parent (Split-Path -Parent $paks)
    $win64=Join-Path $game 'Binaries\Win64'
    foreach ($spec in @(@('UE4SS.dll','8ac18fbffc1ef96b0662d4a2d537b3f224c26d65caaba7989a9404c566102b26'),@('dwmapi.dll','ce596412befa68c30b7f88f65beb77d9bdad55e9b96a276a5a9cf690c63f24bb'))) {
        $file=Join-Path $win64 $spec[0]
        if (!(Test-Path -LiteralPath $file) -or (Hash $file) -ne $spec[1]) { throw 'The verified UE4SS 3.0.1 runtime is required. Run Setup-Runtime.cmd for a fresh installation. Nothing was changed.' }
    }
    $modsPath=Join-Path $win64 'Mods\mods.txt'
    $probePath=Join-Path $win64 'Mods\RCRC_RuntimeProbe\Scripts\main.lua'
    $modsExisted=Test-Path -LiteralPath $modsPath
    $modsText=if ($modsExisted) { [System.IO.File]::ReadAllText($modsPath) } else { '' }
    if ($modsText -match '(?im)^\s*RCRC_ChipMerge\s*:') { throw 'An existing RCRC_ChipMerge entry was found. Use Update-Mod.cmd for an owned installation, or remove the old entry before a fresh install. Other mods unchanged.' }
    $probeInstall=$modsText.Trim() -eq 'RCRC_RuntimeProbe : 1'
    if ($probeInstall) {
        if (!(Test-Path -LiteralPath $probePath) -or @('35a150d736b560f0458898d70a98ca05bea35ad74863365bcf4d4f28149041d8','4ba8546c7476c081da501a16d8a3c6af22fec3e313632b5a94e73eed9bbf3248') -notcontains (Hash $probePath)) { throw 'Diagnostic probe differs from verified version. Nothing changed.' }
    }
    $modFolder=Join-Path $win64 'Mods\RCRC_ChipMerge'
    if (Test-Path -LiteralPath $modFolder) {
        if (!(Test-Path -LiteralPath $modFolder -PathType Container)) { throw 'RCRC_ChipMerge exists as a file. Nothing was overwritten.' }
        $scripts=Join-Path $modFolder 'Scripts'
        $preservedLog=Join-Path $scripts 'RCRC_ChipMerge.log'
        $unexpected=@(Get-ChildItem -LiteralPath $modFolder -Force -Recurse | Where-Object {
            if ($_.PSIsContainer) { $_.FullName -ne $scripts }
            else { $_.FullName -ne $preservedLog }
        })
        if ($unexpected.Count -gt 0) { throw 'RCRC_ChipMerge contains existing scripts or other files. Nothing was overwritten. Finish removing the prior installation first.' }
        Write-Host 'Reusing the empty/log-only folder left by uninstall. Its log will be preserved.'
    }
    $recovery=Join-Path $PSScriptRoot 'Recovery'
    [void](New-Item -ItemType Directory -Path $recovery -Force)
    $backup=Join-Path $recovery 'mods.txt'
    if ($modsExisted) { [System.IO.File]::Copy($modsPath,$backup,$true) }
    $state=[ordered]@{version='1.0.1';win64=$win64;modFolder=$modFolder;modsPath=$modsPath;originalModsExisted=$modsExisted;originalModsHash=$(if ($modsExisted) { Hash $modsPath } else { '' });backupMods=$backup;installedModsHash='';files=@()}
    try {
        [void](New-Item -ItemType Directory -Path (Join-Path $modFolder 'Scripts') -Force)
        foreach ($name in @('main.lua','core.lua','ui.lua','percentage.lua')) {
            $source=Join-Path $PSScriptRoot ('RCRC_ChipMerge\Scripts\'+$name)
            $destination=Join-Path $modFolder ('Scripts\'+$name)
            [System.IO.File]::Copy($source,$destination,$false)
            $state.files += [ordered]@{path=$destination;hash=(Hash $destination)}
            $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
        }
        # Preserve every existing configuration byte; append only our entry.
        $enabled="RCRC_ChipMerge : 1`r`n"
        if ($probeInstall) {
            $enabled="RCRC_RuntimeProbe : 0`r`n"+$enabled
            [IO.File]::WriteAllText($modsPath,$enabled,(New-Object Text.UTF8Encoding($false)))
        } elseif ($modsExisted) {
            $bytes=[IO.File]::ReadAllBytes($modsPath)
            $encoding=New-Object Text.UTF8Encoding($false)
            if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { $encoding=[Text.Encoding]::Unicode }
            elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) { $encoding=[Text.Encoding]::BigEndianUnicode }
            $prefix=if ($modsText.Length -gt 0 -and !$modsText.EndsWith("`n")) { "`r`n" } else { '' }
            $added=$encoding.GetBytes($prefix+$enabled)
            $stream=[IO.File]::Open($modsPath,[IO.FileMode]::Append,[IO.FileAccess]::Write)
            try { $stream.Write($added,0,$added.Length) } finally { $stream.Dispose() }
        } else {
            [void](New-Item -ItemType Directory -Path (Split-Path $modsPath -Parent) -Force)
            [IO.File]::WriteAllText($modsPath,$enabled,(New-Object Text.UTF8Encoding($false)))
        }
        $state.installedModsHash=Hash $modsPath
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
    } catch {
        foreach ($entry in $state.files) { if ((Test-Path -LiteralPath $entry.path) -and (Hash $entry.path) -eq $entry.hash) { Remove-Item -LiteralPath $entry.path } }
        if ($modsExisted) { [System.IO.File]::Copy($backup,$modsPath,$true) } elseif (Test-Path -LiteralPath $modsPath) { Remove-Item -LiteralPath $modsPath }
        if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath }
        throw
    }
    Write-Host 'Installed Tactical Chip Merging 1.0.1. Start the game and select three chips.' -ForegroundColor Green
    Write-Host 'Possible-result range preview is automatic. Click available preview sides to toggle; one side must stay enabled.'
    Write-Host 'Keep this extracted folder for log collection and removal.'
    exit 0
}
if (!(Test-Path -LiteralPath $statePath)) { throw 'InstalledMerge.json was not found. Run this from the same installer folder used for installation.' }
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($Action -eq 'Update') {
    $originalState=[System.IO.File]::ReadAllText($statePath)
    foreach ($entry in $state.files) {
        if (!(Test-Path -LiteralPath $entry.path) -or (Hash $entry.path) -ne $entry.hash) { throw ('Installed script changed or missing: '+$entry.path+'. Nothing was overwritten.') }
    }
    $scriptFolder=Join-Path $state.modFolder 'Scripts'
    $names=@('main.lua','core.lua','ui.lua','percentage.lua')
    foreach ($name in $names) {
        $source=Join-Path $PSScriptRoot ('RCRC_ChipMerge\Scripts\'+$name)
        if (!(Test-Path -LiteralPath $source)) { throw ('Missing update source: '+$source) }
        $destination=Join-Path $scriptFolder $name
        $record=@($state.files | Where-Object { $_.path -eq $destination })
        if ((Test-Path -LiteralPath $destination) -and $record.Count -ne 1) { throw ('Unrecorded file exists: '+$destination+'. Nothing was overwritten.') }
    }
    $backup=Join-Path $PSScriptRoot ('Recovery\UpdateBackup_'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    [void](New-Item -ItemType Directory -Path $backup -Force)
    [System.IO.File]::WriteAllText((Join-Path $backup 'InstalledMerge.json'),$originalState)
    $changed=@()
    try {
        foreach ($name in $names) {
            $destination=Join-Path $scriptFolder $name
            $source=Join-Path $PSScriptRoot ('RCRC_ChipMerge\Scripts\'+$name)
            $existed=Test-Path -LiteralPath $destination
            if ($existed) { [System.IO.File]::Copy($destination,(Join-Path $backup $name),$false) }
            [System.IO.File]::Copy($source,$destination,[bool]$existed)
            $changed += [ordered]@{path=$destination;existed=$existed;backup=(Join-Path $backup $name);hash=(Hash $destination)}
            $record=@($state.files | Where-Object { $_.path -eq $destination })
            if ($record.Count -eq 1) { $record[0].hash=Hash $destination }
            else { $state.files += [pscustomobject]@{path=$destination;hash=(Hash $destination)} }
            $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
        }
        $state.version='1.0.1'
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
    } catch {
        foreach ($entry in $changed) {
            if ((Test-Path -LiteralPath $entry.path) -and (Hash $entry.path) -eq $entry.hash) {
                if ($entry.existed) { [System.IO.File]::Copy($entry.backup,$entry.path,$true) }
                else { Remove-Item -LiteralPath $entry.path }
            }
        }
        [System.IO.File]::WriteAllText($statePath,$originalState)
        throw
    }
    Write-Host 'Updated to 1.0.1. Automatic range preview and side selection enabled; menu ancestor settings untouched.' -ForegroundColor Green
    exit 0
}
if ($Action -eq 'Collect') {
    $stage=Join-Path ([IO.Path]::GetTempPath()) ('RCRC_Report_'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $notes=[Collections.Generic.List[string]]::new()
    try {
        foreach ($path in @((Join-Path $state.modFolder 'Scripts\RCRC_ChipMerge.log'),(Join-Path $state.win64 'UE4SS.log'))) {
            if (Test-Path -LiteralPath $path -PathType Leaf) { Copy-Item -LiteralPath $path -Destination $stage }
        }
        $savedRoots=@((Join-Path (Split-Path (Split-Path $state.win64 -Parent) -Parent) 'Saved'))
        if ($env:LOCALAPPDATA) {
            $savedRoots+=Join-Path $env:LOCALAPPDATA 'RoboCop\Saved'
            $savedRoots+=@(Get-ChildItem -LiteralPath $env:LOCALAPPDATA -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like '*RoboCop*' } | ForEach-Object { Join-Path $_.FullName 'Saved' })
        }
        $index=0
        foreach ($saved in ($savedRoots | Select-Object -Unique)) {
            if (-not (Test-Path -LiteralPath $saved -PathType Container)) { continue }
            $index++
            $logs=Join-Path $saved 'Logs'
            foreach ($file in @(Get-ChildItem -LiteralPath $logs -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $stage ('Engine_'+$index+'_'+$file.Name))
                $notes.Add('Engine log: '+$file.FullName)
            }
            $crashes=Join-Path $saved 'Crashes'
            foreach ($crash in @(Get-ChildItem -LiteralPath $crashes -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)) {
                $target=Join-Path $stage ('Crash_'+$index+'_'+$crash.Name)
                New-Item -ItemType Directory -Path $target -Force | Out-Null
                foreach ($file in @(Get-ChildItem -LiteralPath $crash.FullName -File -Recurse | Where-Object { $_.Extension -in @('.xml','.runtime-xml','.log','.txt') })) {
                    $relative=$file.FullName.Substring($crash.FullName.Length).TrimStart([char[]]@('\','/'))
                    $destination=Join-Path $target $relative
                    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
                    Copy-Item -LiteralPath $file.FullName -Destination $destination
                }
                $notes.Add('Crash details: '+$crash.FullName)
            }
        }
        if ($notes.Count -eq 0) { $notes.Add('No game engine/crash text files found in the checked Saved folders. Crash cause remains undetermined.') }
        $notes | Set-Content -LiteralPath (Join-Path $stage 'CrashCollection.txt')
        $output=Join-Path $PSScriptRoot ('RCRC_ChipMerge_Report_'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.zip')
        Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $output
        Write-Host 'Upload this report ZIP (includes available game crash text, without memory dumps):' -ForegroundColor Green
        Write-Host $output
    } finally { Remove-Item -LiteralPath $stage -Recurse -Force }
    exit 0
}

# The launcher reminds the user to close the game; never remove loader DLLs.
if ((Test-Path -LiteralPath $state.modsPath) -and (Hash $state.modsPath) -eq $state.installedModsHash) {
    $originalExisted=if ($state.PSObject.Properties['originalModsExisted']) { $state.originalModsExisted } else { $true }
    if (!$originalExisted) { Remove-Item -LiteralPath $state.modsPath } else {
    if (!(Test-Path -LiteralPath $state.backupMods) -or (Hash $state.backupMods) -ne $state.originalModsHash) { throw 'The configuration backup is missing or changed. Nothing was removed.' }
    [System.IO.File]::Copy($state.backupMods,$state.modsPath,$true)
    }
} else { Write-Host 'Keeping changed mods.txt. Remove its RCRC_ChipMerge entry manually if present.' }
$remaining=@()
foreach ($entry in $state.files) {
    if (Test-Path -LiteralPath $entry.path) {
        if ((Hash $entry.path) -eq $entry.hash) { Remove-Item -LiteralPath $entry.path }
        else { Write-Host ('Keeping changed file: '+$entry.path);$remaining += $entry }
    }
}
foreach ($folder in @((Join-Path $state.modFolder 'Scripts'),$state.modFolder)) {
    if ((Test-Path -LiteralPath $folder -PathType Container) -and @(Get-ChildItem -LiteralPath $folder -Force).Count -eq 0) { Remove-Item -LiteralPath $folder }
}
if ($remaining.Count -eq 0) { Remove-Item -LiteralPath $statePath }
else { $state.files=$remaining;$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8 }
Write-Host 'Removed unchanged Tactical Chip Merging files and restored the original configuration when unchanged. Logs are preserved.' -ForegroundColor Green
