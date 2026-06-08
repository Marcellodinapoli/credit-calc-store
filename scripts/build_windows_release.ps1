# Build release Windows e installer Setup.exe (Inno Setup 6).
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_release.ps1
#
# Output fisso:
#   dist\CreditCalc-<version>-win64\CreditCalc.exe
#   dist\CreditCalc-<version>-Setup.exe

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$core = Join-Path $root "packages\credit_calc_core"
$tools = Join-Path $root "tools"
$pubspecPath = Join-Path $root "pubspec.yaml"

function Get-AppVersion {
    $line = Get-Content $pubspecPath | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
    if ($line -match 'version:\s*(\d+\.\d+\.\d+)') {
        return $Matches[1]
    }
    return "1.0.0"
}

function Get-InnoSetupCompiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$version = Get-AppVersion
Write-Host "==> CreditCalc $version - build Windows release"

if (-not (Test-Path (Join-Path $tools "nuget.exe"))) {
    New-Item -ItemType Directory -Force -Path $tools | Out-Null
    Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" `
        -OutFile (Join-Path $tools "nuget.exe")
}
$env:PATH = "$tools;$env:PATH"

function Add-AtlIncludePath {
    $vsRoot = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
    if (-not (Test-Path $vsRoot)) {
        $vsRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community"
    }
    $msvcRoot = Join-Path $vsRoot "VC\Tools\MSVC"
    if (-not (Test-Path $msvcRoot)) { return }

    $atlInclude = Get-ChildItem $msvcRoot -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "atlmfc\include" } |
        Where-Object { Test-Path (Join-Path $_ "atlbase.h") } |
        Select-Object -First 1

    if ($atlInclude) {
        if ($env:INCLUDE) {
            $env:INCLUDE = "$atlInclude;$env:INCLUDE"
        } else {
            $env:INCLUDE = $atlInclude
        }
        Write-Host "==> ATL include: $atlInclude"

        $atlLib = Join-Path (Split-Path $atlInclude -Parent) "lib\x64"
        if (-not (Test-Path (Join-Path $atlLib "atls.lib"))) {
            $atlLib = Join-Path (Split-Path $atlInclude -Parent) "..\lib\x64" | Resolve-Path -ErrorAction SilentlyContinue
            if ($atlLib) { $atlLib = $atlLib.Path }
        }
        if (Test-Path (Join-Path $atlLib "atls.lib")) {
            if ($env:LIB) {
                $env:LIB = "$atlLib;$env:LIB"
            } else {
                $env:LIB = $atlLib
            }
            Write-Host "==> ATL lib: $atlLib"
        }
    }
}

Add-AtlIncludePath

function Patch-NotificationsAtlCmake {
    $cmake = Join-Path $root "windows\flutter\ephemeral\.plugin_symlinks\flutter_local_notifications_windows\src\CMakeLists.txt"
    if (-not (Test-Path $cmake)) { return }

    $marker = "CreditCalc: MSVC ATL"
    $content = Get-Content $cmake -Raw
    if ($content -match [regex]::Escape($marker)) { return }

    $patch = @'

# CreditCalc: MSVC ATL for flutter_local_notifications_windows
file(GLOB _creditcalc_atl_inc
  "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/*/atlmfc/include"
  "C:/Program Files/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/*/atlmfc/include"
)
foreach(_dir ${_creditcalc_atl_inc})
  if(EXISTS "${_dir}/atlbase.h")
    get_filename_component(_msvc "${_dir}" DIRECTORY)
    get_filename_component(_msvc "${_msvc}" DIRECTORY)
    set(_lib "${_msvc}/atlmfc/lib/x64")
    target_include_directories(flutter_local_notifications_windows PRIVATE "${_dir}")
    target_link_libraries(flutter_local_notifications_windows PRIVATE "${_lib}/atls.lib")
    set_target_properties(flutter_local_notifications_windows PROPERTIES VS_GLOBAL_UseOfAtl "Static")
    break()
  endif()
endforeach()
'@

    Add-Content -Path $cmake -Value $patch -Encoding UTF8
    Write-Host "==> Patch ATL su flutter_local_notifications_windows"
}

Write-Host "==> pub get (core + app)"
Push-Location $core
flutter pub get
Pop-Location

Push-Location $root
flutter pub get
Patch-NotificationsAtlCmake
flutter build windows --release
Pop-Location

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "CreditCalc.exe"
$dllPath = Join-Path $releaseDir "flutter_windows.dll"
if (-not (Test-Path $exePath) -or -not (Test-Path $dllPath)) {
    throw "Build non riuscita: mancano CreditCalc.exe o flutter_windows.dll in $releaseDir"
}

$distRoot = Join-Path $root "dist"
$folderName = "CreditCalc-$version-win64"
$outDir = Join-Path $distRoot $folderName
$setupPath = Join-Path $distRoot "CreditCalc-$version-Setup.exe"

if (Test-Path $outDir) {
    Remove-Item $outDir -Recurse -Force
}
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host "==> Copia bundle in $outDir"
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $outDir -Recurse

$iscc = Get-InnoSetupCompiler
if (-not $iscc) {
    throw @"
Inno Setup 6 non trovato.
Installa da https://jrsoftware.org/isdl.php e riesegui lo script.
"@
}

if (Test-Path $setupPath) { Remove-Item $setupPath -Force }
$iss = Join-Path $root "installer\CreditCalcSetup.iss"
Write-Host "==> Crea installer $setupPath (Inno Setup)"
& $iscc "/DMyAppVersion=$version" "/DSourceDir=$outDir" $iss
if (-not (Test-Path $setupPath)) {
    throw "Compilazione installer non riuscita: $setupPath"
}

$distReadme = @(
    "FILE UNICO DA DISTRIBUIRE"
    "========================="
    ""
    "  $setupPath"
    ""
    "Cartella applicazione (sviluppo/test):"
    "  $outDir\CreditCalc.exe"
)
Set-Content -Path (Join-Path $distRoot "LEGGIMI-DISTRIBUZIONE.txt") -Value $distReadme -Encoding UTF8

Write-Host ''
Write-Host '========================================'
Write-Host '  FILE DA DARE AGLI UTENTI:'
Write-Host "  $setupPath"
Write-Host '========================================'
Write-Host ''
Write-Host "  App portable: $outDir\CreditCalc.exe"
