[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ToolRoot {
    param(
        [string[]]$Candidates,
        [Parameter(Mandatory = $true)]
        [string]$Marker
    )

    foreach ($candidate in @($Candidates | Where-Object { $_ })) {
        if (Test-Path -LiteralPath (Join-Path $candidate $Marker)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return ''
}

if (-not (Test-Path -LiteralPath $ProjectRoot)) { throw "Project path is missing: $ProjectRoot" }
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$workspaceRoot = Split-Path -Parent $ProjectRoot
$toolchainsRoot = Join-Path $workspaceRoot '.toolchains'
$bundledJdkParent = Join-Path $toolchainsRoot 'jdk17'
$bundledJdk = if (Test-Path -LiteralPath $bundledJdkParent) {
    Get-ChildItem -LiteralPath $bundledJdkParent -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
        Select-Object -First 1 -ExpandProperty FullName
} else {
    ''
}

$flutterRoot = Resolve-ToolRoot -Marker 'bin\flutter.bat' -Candidates @(
    $env:FLUTTER_ROOT,
    (Join-Path $toolchainsRoot 'flutter'),
    'D:\Dev\Flutter\3.44.9'
)
$javaRoot = Resolve-ToolRoot -Marker 'bin\java.exe' -Candidates @(
    $env:JAVA_HOME,
    $bundledJdk,
    'F:\Codex\home\tools\jdk17'
)
$androidSdk = Resolve-ToolRoot -Marker 'platform-tools\adb.exe' -Candidates @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    (Join-Path $toolchainsRoot 'android-sdk'),
    'F:\Codex\home\tools\android-sdk'
)

if (-not $flutterRoot -or -not (Test-Path (Join-Path $flutterRoot 'bin\flutter.bat'))) { throw 'Set FLUTTER_ROOT to a Flutter 3.44.9 installation.' }
if (-not $javaRoot -or -not (Test-Path (Join-Path $javaRoot 'bin\java.exe'))) { throw 'Set JAVA_HOME to a JDK 17 installation.' }
if (-not $androidSdk -or -not (Test-Path (Join-Path $androidSdk 'platform-tools\adb.exe'))) { throw 'Set ANDROID_SDK_ROOT to an Android SDK installation.' }

$pubCache = Join-Path $toolchainsRoot 'pub-cache'
$gradleUserHome = Join-Path $toolchainsRoot 'gradle-home'
$androidUserHome = Join-Path $toolchainsRoot 'android-user-home'
New-Item -ItemType Directory -Force -Path $pubCache, $gradleUserHome, $androidUserHome | Out-Null

$env:SAIDIAN_APP_ROOT = $ProjectRoot
$env:FLUTTER_ROOT = $flutterRoot
$env:JAVA_HOME = $javaRoot
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:PUB_CACHE = $pubCache
$env:GRADLE_USER_HOME = $gradleUserHome
$env:ANDROID_USER_HOME = $androidUserHome
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:Path = (@(
    (Join-Path $flutterRoot 'bin'),
    (Join-Path $javaRoot 'bin'),
    (Join-Path $androidSdk 'platform-tools'),
    (Join-Path $androidSdk 'cmdline-tools\latest\bin')
) + @($env:Path -split ';' | Where-Object { $_ }) | Select-Object -Unique) -join ';'

Set-Location -LiteralPath $ProjectRoot
if (-not $Quiet) {
    Write-Host 'Saidian App development environment is ready.' -ForegroundColor Green
    Write-Host "Project : $ProjectRoot"
    Write-Host "Flutter : $flutterRoot"
    Write-Host "JDK     : $javaRoot"
    Write-Host "SDK     : $androidSdk"
    Write-Host 'Device  : Run .\tool\handoff\Run-AndroidDebug.ps1 to use the connected physical phone.'
}
