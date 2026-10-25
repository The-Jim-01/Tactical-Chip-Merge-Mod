param([ValidateSet('Install','Uninstall')][string]$Action='Install',[string]$ArchivePath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$record=Join-Path $PSScriptRoot 'InstalledRuntime.json'
function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
if ($Action -eq 'Uninstall') {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'InstalledMerge.json')) { throw 'Remove Tactical Chip Merging with Uninstall-Mod.cmd first.' }
    if (!(Test-Path -LiteralPath $record)) { throw 'No runtime installed by this package was recorded. Nothing was removed.' }
    $state=Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
    foreach ($entry in $state.files) {
        if (!(Test-Path -LiteralPath $entry.path) -or (Hash $entry.path) -ne $entry.hash) { throw ('Owned runtime file changed or missing: '+$entry.path+'. Nothing was removed.') }
    }
    $mods=Join-Path $state.win64 'Mods'
    $extra=@(Get-ChildItem -LiteralPath $mods -File -Recurse | Where-Object { $_.FullName -ne (Join-Path $mods 'mods.txt') -and $_.Extension -ne '.log' })
    if ($extra.Count -gt 0) { throw 'Additional mod files remain. Runtime removal would affect them; nothing was removed.' }
    foreach ($entry in $state.files) { Remove-Item -LiteralPath $entry.path }
    foreach ($dir in @($mods)) { if (@(Get-ChildItem -LiteralPath $dir -Force).Count -eq 0) { Remove-Item -LiteralPath $dir } }
    Remove-Item -LiteralPath $record
    Write-Host 'Removed unchanged runtime files owned by this package. Logs remain.' -ForegroundColor Green
    exit 0
}
if (Test-Path -LiteralPath $record) { throw 'This package already installed a runtime. Use Install-Mod.cmd or Update-Mod.cmd instead.' }
$paks=(Read-Host 'Paste the full path to Game\Content\Paks').Trim().Trim('"')
$paks=(Resolve-Path -LiteralPath $paks).Path
if (!(Test-Path -LiteralPath (Join-Path $paks 'pakchunk0-Windows.utoc')) -or (Hash (Join-Path $paks 'pakchunk0-Windows.utoc')) -ne '7cb150a5f59b78fe53785eb69001af01d63593560fdd2d8063adf3481fee2ab4') { throw 'Unsupported game archive. This setup targets the verified GOG 1.0.2.1 archive only.' }
$game=Split-Path -Parent (Split-Path -Parent $paks)
$win64=Join-Path $game 'Binaries\Win64'
if (!(Test-Path -LiteralPath $win64 -PathType Container)) { throw 'Game\Binaries\Win64 was not found.' }
# Reuse only the verified compatible runtime; never overwrite another loader.
$dll=Join-Path $win64 'UE4SS.dll'
$proxy=Join-Path $win64 'dwmapi.dll'
$settingsFile=Join-Path $win64 'UE4SS-settings.ini'
if (Test-Path -LiteralPath $dll) {
    if (!(Test-Path -LiteralPath $proxy) -or (Hash $dll) -ne '8ac18fbffc1ef96b0662d4a2d537b3f224c26d65caaba7989a9404c566102b26' -or (Hash $proxy) -ne 'ce596412befa68c30b7f88f65beb77d9bdad55e9b96a276a5a9cf690c63f24bb') { throw 'Existing runtime is not the verified UE4SS 3.0.1 loader. Nothing overwritten.' }
    if (!(Test-Path -LiteralPath $settingsFile) -or [IO.File]::ReadAllText($settingsFile) -notmatch '(?m)^bUseUObjectArrayCache\s*=\s*false\s*$') { throw 'Existing runtime requires bUseUObjectArrayCache = false in UE4SS-settings.ini. Settings were preserved; set this value before retrying.' }
    Write-Host 'Reusing verified UE4SS 3.0.1. Existing runtime and mods unchanged. Run Install-Mod.cmd.' -ForegroundColor Green
    exit 0
}
foreach ($name in @('dwmapi.dll','UE4SS-settings.ini','xinput1_3.dll')) {
    if (Test-Path -LiteralPath (Join-Path $win64 $name)) { throw ('Existing '+$name+' conflicts with runtime setup. Nothing overwritten.') }
}
$existingMods=Join-Path $win64 'Mods'
if ((Test-Path -LiteralPath $existingMods) -and !(Test-Path -LiteralPath $existingMods -PathType Container)) { throw 'Mods exists as a file. Nothing overwritten.' }
$temp=Join-Path ([IO.Path]::GetTempPath()) ('TacticalChipMerging_'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$state=[ordered]@{version='3.0.1';win64=$win64;files=@()}
try {
    $archive=Join-Path $temp 'UE4SS.zip'
    if ($ArchivePath) { Copy-Item -LiteralPath $ArchivePath -Destination $archive }
    else {
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Write-Host 'Downloading the verified official UE4SS 3.0.1 release.'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v3.0.1/UE4SS_v3.0.1.zip' -OutFile $archive
    }
    if ((Hash $archive) -ne '4b47d4bceddd2f561a4e395bfa00924ccfc945af576a2d0c613e6537846c57ec') { throw 'Runtime archive hash mismatch. Nothing was installed.' }
    $unpacked=Join-Path $temp 'release'
    Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
    $settingsPath=Join-Path $unpacked 'UE4SS-settings.ini'
    $settings=[IO.File]::ReadAllText($settingsPath)
    $settings=$settings -replace '(?m)^bUseUObjectArrayCache\s*=.*$','bUseUObjectArrayCache = false'
    $settings=$settings -replace '(?m)^GuiConsoleEnabled\s*=.*$','GuiConsoleEnabled = 0'
    [IO.File]::WriteAllText($settingsPath,$settings,(New-Object Text.UTF8Encoding($false)))
    $modsText=Join-Path $temp 'mods.txt'
    [IO.File]::WriteAllText($modsText,'',(New-Object Text.UTF8Encoding($false)))
    $pairs=@(@('UE4SS.dll',(Join-Path $unpacked 'UE4SS.dll')),@('dwmapi.dll',(Join-Path $unpacked 'dwmapi.dll')),@('UE4SS-settings.ini',$settingsPath))
    if (!(Test-Path -LiteralPath (Join-Path $win64 'Mods\mods.txt'))) { $pairs+=,@('Mods\mods.txt',$modsText) }
    foreach ($pair in $pairs) {
        $destination=Join-Path $win64 $pair[0]
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        [IO.File]::Copy($pair[1],$destination,$false)
        $state.files+= [ordered]@{path=$destination;hash=(Hash $destination)}
        $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $record -Encoding UTF8
    }
} catch {
    foreach ($entry in $state.files) {
        if ((Test-Path -LiteralPath $entry.path) -and (Hash $entry.path) -eq $entry.hash) { Remove-Item -LiteralPath $entry.path }
    }
    $mods=Join-Path $win64 'Mods'
    if ((Test-Path -LiteralPath $mods) -and @(Get-ChildItem -LiteralPath $mods -Force).Count -eq 0) { Remove-Item -LiteralPath $mods }
    if (Test-Path -LiteralPath $record) { Remove-Item -LiteralPath $record }
    throw
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
Write-Host 'UE4SS 3.0.1 installed. Run Install-Mod.cmd next.' -ForegroundColor Green
