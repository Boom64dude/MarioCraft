# MarioCraft: puts a "MarioCraft" instance into Prism Launcher (Minecraft 26.3, Fabric, Fabric API,
# e4mc and the MarioCraft mod), or brings its mods up to date. Prism plays it with the Microsoft
# account you signed in to Prism with, so your own skin shows up in SM64 (and to other players).
#
# Run by "MarioCraft Launcher.exe" before every start (quick when nothing changed), or by hand:
#   powershell -ExecutionPolicy Bypass -File launcher\setup-prism.ps1
#
# Which Prism: the installed one (%APPDATA%\PrismLauncher), else SkyCraft's portable one
# (%LOCALAPPDATA%\SkyCraft\Prism). Only the MarioCraft instance is touched.
param([switch]$Quiet)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Say([string]$text) { if (-not $Quiet) { Write-Host $text } }

# Where Prism keeps its instances, and its program.
$installedData = Join-Path $env:APPDATA "PrismLauncher"
$installedExe = @("$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe", "$env:ProgramFiles\PrismLauncher\prismlauncher.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
$portable = Join-Path $env:LOCALAPPDATA "SkyCraft\Prism"
if ($installedExe -and (Test-Path $installedData)) {
    $prismExe = $installedExe
    $data = $installedData
} elseif (Test-Path "$portable\prismlauncher.exe") {
    $prismExe = "$portable\prismlauncher.exe"
    $data = $portable
} elseif ($installedExe) {
    throw "Prism Launcher is installed but hasn't been opened yet. Open it once, sign in (Accounts, top right: Manage Accounts, Add Microsoft) with the account that owns Minecraft, close it, then try again."
} else {
    throw "Prism Launcher isn't installed. Get it from https://prismlauncher.org, sign in to your Microsoft account in it once, then try again."
}

# The jars: Fabric API and e4mc pinned as SkyCraft pins them (checked against the same hashes),
# taken from SkyCraft's own Prism copy or this project's cache; the MarioCraft mod from the build.
$pins = @(
    @{ Name = "fabric-api-0.161.0+26.3.jar"; Url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/bNnaTiuM/fabric-api-0.161.0%2B26.3.jar";
       Sha512 = "ed6b2586d6fde11fde8472f5a527c51e99b67026e46f94d4bfd85e7e28ce5ee299173ee16ad576ceb51f39f98d30a811086a6deb1a86a524859cc16e12da109d" },
    @{ Name = "e4mc-fabric-6.2.2-modern.jar"; Url = "https://cdn.modrinth.com/data/qANg5Jrr/versions/AouleFRY/e4mc-fabric-6.2.2-modern.jar";
       Sha512 = "01ef0a8c5b76e2cb0effd337bad3350d8807d100d0ec661e01b2ffb20af7b652f756c5eaa11bee233c37905bfd7b573f7a85f3d15bfd2833962c76f02cd59a86" }
)
$cache = Join-Path $PSScriptRoot "cache"
$skycraftMods = Join-Path $env:LOCALAPPDATA "SkyCraft\Prism\instances\SkyCraft\.minecraft\mods"

function Get-PinnedJar($pin) {
    $cached = Join-Path $cache $pin.Name
    foreach ($candidate in @($cached, (Join-Path $skycraftMods $pin.Name))) {
        if ((Test-Path $candidate) -and (Get-FileHash $candidate -Algorithm SHA512).Hash -eq $pin.Sha512.ToUpper()) {
            return $candidate
        }
    }
    Say "Downloading $($pin.Name)..."
    New-Item -ItemType Directory $cache -Force | Out-Null
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $pin.Url -OutFile $cached -UseBasicParsing
    if ((Get-FileHash $cached -Algorithm SHA512).Hash -ne $pin.Sha512.ToUpper()) {
        Remove-Item $cached
        throw "$($pin.Name) didn't match its pinned hash"
    }
    return $cached
}

$modJar = Get-ChildItem "$root\SkyCraft\fabric\build\libs\skycraft-*.jar" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '-sources' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $modJar) {
    throw "The MarioCraft Minecraft mod isn't built yet: in SkyCraft\fabric run .\gradlew build"
}

# The instance.
$instance = Join-Path $data "instances\MarioCraft"
$mods = Join-Path $instance ".minecraft\mods"
$new = -not (Test-Path "$instance\instance.cfg")
New-Item -ItemType Directory $mods -Force | Out-Null
if ($new) {
    Say "Adding the MarioCraft instance to Prism ($data)"
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $cfg = @"
[General]
InstanceType=OneSix
name=MarioCraft
iconKey=default
notes=Managed by MarioCraft: "MarioCraft Launcher.exe" starts this instance hidden next to Super Mario 64, and updates its mods (MarioCraft, Fabric API, e4mc).
OverrideJavaArgs=true
JvmArgs=--enable-native-access=ALL-UNNAMED -Dskycraft.startHidden=true -Dskycraft.discordAppId=0
OverrideMemory=true
MinMemAlloc=512
MaxMemAlloc=4096
OverrideConsole=true
ShowConsole=false
AutoCloseConsole=false
ShowConsoleOnError=true
"@
    [System.IO.File]::WriteAllText("$instance\instance.cfg", $cfg.Replace("`r`n", "`n"), $utf8)
    Copy-Item "$root\SkyCraft\tools\minecraft-bundle\Prism\instances\SkyCraft\mmc-pack.json" "$instance\mmc-pack.json"
}

# Mods: replace ours (and the pinned ones) whenever they differ; leave anything else the player added.
function Sync-Jar([string]$source, [string]$pattern, [string]$name) {
    $dest = Join-Path $mods $name
    Get-ChildItem $mods -Filter $pattern | Where-Object { $_.Name -ne $name } | Remove-Item -Force
    if (-not (Test-Path $dest) -or (Get-FileHash $dest).Hash -ne (Get-FileHash $source).Hash) {
        Copy-Item $source $dest -Force
        Say "Updated $name"
    }
}
foreach ($pin in $pins) {
    $pattern = if ($pin.Name -like "fabric-api-*") { "fabric-api-*.jar" } else { "e4mc-*.jar" }
    Sync-Jar (Get-PinnedJar $pin) $pattern $pin.Name
}
Sync-Jar $modJar.FullName "skycraft-*.jar" $modJar.Name

# For the launcher: which Prism to start.
Set-Content (Join-Path $PSScriptRoot "prism-path.txt") $prismExe -Encoding ASCII
Say "MarioCraft instance ready in $data"
