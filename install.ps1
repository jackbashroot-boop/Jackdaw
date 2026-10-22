#Requires -Version 5.1
<#
.SYNOPSIS
  Jackdaw installer for Windows.

.EXAMPLE
  irm https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1 | iex

.EXAMPLE
  & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1'))) -Uninstall
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$Repo = 'jackbashroot-boop/Jackdaw'
$Base = "https://github.com/$Repo/releases"
$Bin  = 'jackdaw'

function Say  { param([string]$m) Write-Host $m }
function Info { param([string]$m) Write-Host "  $m" }
# Write-Error under ErrorActionPreference=Stop throws before exit 1 runs, which
# wraps the message in an exception dump. Write-Host then exit is cleaner.
function Die  { param([string]$m) Write-Host "jackdaw: $m" -ForegroundColor Red; exit 1 }

$RootDir = if ($env:JACKDAW_HOME) { $env:JACKDAW_HOME } else { Join-Path $env:LOCALAPPDATA 'Jackdaw' }
$BinDir  = Join-Path $RootDir 'bin'

if ($Uninstall) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $BinDir "$Bin.cmd")
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $RootDir
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -and (($userPath -split ';') -contains $BinDir)) {
        $cleaned = ($userPath -split ';' | Where-Object { $_ -and $_ -ne $BinDir }) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')
        Info "Removed $BinDir from your user PATH."
    }
    Say 'jackdaw uninstalled.'
    exit 0
}

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    default { Die "unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

$rid   = "win-$arch"
$asset = "$Bin-$rid.tar.gz"
$url   = if ($Version) { "$Base/download/v$($Version.TrimStart('v'))/$asset" } else { "$Base/latest/download/$asset" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("jackdaw-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Say "Downloading $asset"
    Invoke-RestMethod -Uri $url -OutFile (Join-Path $tmp $asset)
    Invoke-RestMethod -Uri "$url.sha256" -OutFile (Join-Path $tmp "$asset.sha256")

    Say 'Verifying checksum'
    $expected = ((Get-Content (Join-Path $tmp "$asset.sha256") -Raw) -split '\s+')[0].ToLowerInvariant()
    $actual   = (Get-FileHash (Join-Path $tmp $asset) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expected -ne $actual) { Die 'checksum mismatch; refusing to install' }

    $stage = Join-Path $RootDir 'current.tmp'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stage
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    tar -xzf (Join-Path $tmp $asset) -C $stage
    if ($LASTEXITCODE -ne 0) { Die 'tar extraction failed (needs Windows 10 1803 or newer)' }

    $exe = Join-Path $stage "$Bin.exe"
    if (-not (Test-Path $exe)) { Die "archive did not contain $Bin.exe" }

    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $RootDir 'previous')
    if (Test-Path (Join-Path $RootDir 'current')) {
        Move-Item (Join-Path $RootDir 'current') (Join-Path $RootDir 'previous')
    }
    Move-Item $stage (Join-Path $RootDir 'current')

    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $shim = Join-Path $BinDir "$Bin.cmd"
    "@echo off`r`n`"%~dp0..\current\$Bin.exe`" %*" | Set-Content -Path $shim -Encoding ASCII

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $BinDir) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $BinDir } else { "$userPath;$BinDir" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = "$env:Path;$BinDir"
        Say ''
        Say "Added $BinDir to your user PATH. Open a new terminal for it to take effect."
    }

    Say ''
    Say "Installed to $RootDir\current"
    & $exe version
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
}
