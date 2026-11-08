# Build Wordloom-<version>-x64.msi from a release build.
#
# Needs: Rust (MSVC toolchain), Visual Studio or the Build Tools with the C++
# workload, Qt 6 for MSVC 64-bit with windeployqt on PATH (or QT_ROOT_DIR
# set, as jurplel/install-qt-action does), and the .NET SDK for the WiX
# Toolset, which this script installs as a .NET tool if `wix` is missing.
# Run from the repository root:  packaging\windows\build-msi.ps1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$here = "$root\packaging\windows"
$stage = "$root\target\msi\stage"
$work = "$root\target\msi"
Set-Location $root

function Check($what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed with exit code $LASTEXITCODE" }
}

# The version comes from the workspace Cargo.toml ([workspace.package]).
$version = (Select-String -Path "$root\Cargo.toml" -Pattern '^version\s*=\s*"([^"]+)"' |
    Select-Object -First 1).Matches[0].Groups[1].Value
# An MSI version is three numbers; drop any pre-release suffix (0.2.0-beta.1).
$msiVersion = ($version -split '[-+]')[0]

cargo build --release -p wordloom; Check 'cargo build'

# Stage the app with everything Qt needs next to it.
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item "$root\target\release\wordloom.exe" $stage

$windeployqt = Get-Command windeployqt -ErrorAction SilentlyContinue
if ($windeployqt) { $windeployqt = $windeployqt.Source }
elseif ($env:QT_ROOT_DIR) { $windeployqt = "$env:QT_ROOT_DIR\bin\windeployqt.exe" }
else { throw 'windeployqt not found: put Qt''s bin folder on PATH or set QT_ROOT_DIR.' }
& $windeployqt --release --no-translations --no-compiler-runtime `
    --qmldir "$root\crates\wordloom-app\qml" "$stage\wordloom.exe"
Check 'windeployqt'

# The Visual C++ runtime, app-local (so users don't need the redistributable).
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$crt = & $vswhere -latest -products * -find 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT' |
    Select-Object -Last 1
if (-not $crt) { throw 'The Visual C++ runtime (VC\Redist\MSVC) was not found.' }
Copy-Item "$crt\*.dll" $stage

# The licence the installer shows, as minimal RTF.
$text = (Get-Content -Raw "$root\LICENSE") -replace '\\', '\\' -replace '\{', '\{' -replace '\}', '\}'
$text = $text -replace "`r?`n", "\par`n"
Set-Content -Encoding Ascii "$work\License.rtf" "{\rtf1\ansi\deff0{\fonttbl{\f0 Segoe UI;}}\f0\fs18`n$text}"

if (-not (Get-Command wix -ErrorAction SilentlyContinue)) {
    dotnet tool install --global wix --version 5.0.2; Check 'Installing WiX'
    $env:PATH += ";$env:USERPROFILE\.dotnet\tools"
}
wix extension add -g WixToolset.UI.wixext/5.0.2; Check 'Adding the WiX UI extension'

$out = "$root\Wordloom-$version-x64.msi"
Push-Location $here
try {
    wix build Wordloom.wxs -arch x64 -ext WixToolset.UI.wixext `
        -d "Version=$msiVersion" -d "StageDir=$stage" -d "LicenseRtf=$work\License.rtf" `
        -o $out
    Check 'wix build'
} finally { Pop-Location }
Write-Host "Built $out"
