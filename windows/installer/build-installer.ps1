[CmdletBinding()]
param(
    [switch]$ValidateOnly,
    [switch]$SkipFlutterBuild,
    [string]$IsccPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pubspecPath = Join-Path $repositoryRoot 'pubspec.yaml'
$issPath = Join-Path $PSScriptRoot 'hermes_mobile.iss'
$bundlePath = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
$outputPath = Join-Path $repositoryRoot 'build\installer'
$executablePath = Join-Path $bundlePath 'hermes_mobile.exe'

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Description
    )

    if (-not (Select-String -LiteralPath $Path -Pattern $Pattern -Quiet)) {
        throw "Installer validation failed: $Description"
    }
}

if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
    throw "pubspec.yaml was not found at '$pubspecPath'."
}
if (-not (Test-Path -LiteralPath $issPath -PathType Leaf)) {
    throw "Inno Setup script was not found at '$issPath'."
}

$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$' | Select-Object -First 1
if (-not $versionMatch) {
    throw "Could not read a semantic application version from '$pubspecPath'. Expected: version: x.y.z+build"
}
$appVersion = $versionMatch.Matches[0].Groups[1].Value

Assert-FileContains $issPath '^AppId=\{\{[0-9A-Fa-f-]{36}\}$' 'a stable AppId is required.'
Assert-FileContains $issPath '^PrivilegesRequired=lowest$' 'per-user installation must use PrivilegesRequired=lowest.'
Assert-FileContains $issPath '^DefaultDirName=\{localappdata\}' 'the install directory must be under the current user profile.'
Assert-FileContains $issPath '^Name: "\{group\}' 'a Start menu shortcut is required.'
Assert-FileContains $issPath '^Name: "desktopicon".*Flags: unchecked$' 'the desktop shortcut must be optional and unchecked by default.'
Assert-FileContains $issPath '^UninstallDisplayIcon=' 'uninstall metadata is required.'
Assert-FileContains $issPath '^Filename: ".*"; Description: ".*"; Flags: nowait postinstall skipifsilent$' 'post-install launch behavior is required.'
Assert-FileContains $issPath '^Source: "\{#BundleDir\}\\\*";.*recursesubdirs createallsubdirs$' 'the complete Release bundle must be packaged recursively.'

if ($ValidateOnly) {
    Write-Host "Installer scripts validated successfully for version $appVersion."
    exit 0
}

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    throw "Flutter was not found on PATH. Install Flutter or add its bin directory to PATH."
}

if (-not $SkipFlutterBuild) {
    Write-Host 'Building Flutter Windows Release bundle...'
    & $flutter.Source build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows --release failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $bundlePath -PathType Container)) {
    throw "Windows Release bundle was not found at '$bundlePath'. Run flutter build windows --release first."
}
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Windows Release executable was not found at '$executablePath'. The Release bundle is incomplete."
}
foreach ($requiredPath in @('flutter_windows.dll', 'data\flutter_assets', 'data\icudtl.dat', 'data\app.so')) {
    $fullPath = Join-Path $bundlePath $requiredPath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Windows Release bundle is incomplete: missing '$fullPath'."
    }
}

if (-not $IsccPath) {
    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($isccCommand) {
        $IsccPath = $isccCommand.Source
    } else {
        $isccCandidates = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
        $IsccPath = $isccCandidates | Select-Object -First 1
    }
}
if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) {
    throw "ISCC.exe was not found. Install Inno Setup 6, add ISCC.exe to PATH, or pass -IsccPath '<path>'."
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
Write-Host "Compiling Hermes Mobile $appVersion installer..."
& $IsccPath "/DAppVersion=$appVersion" "/DBundleDir=$bundlePath" "/DInstallerOutputDir=$outputPath" $issPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe failed with exit code $LASTEXITCODE."
}

$installerPath = Join-Path $outputPath "HermesMobile-Setup-$appVersion-x64.exe"
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "ISCC.exe completed but the expected installer was not found at '$installerPath'."
}
Write-Host "Installer created: $installerPath"
