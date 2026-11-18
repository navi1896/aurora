<#
.SYNOPSIS
    Converts an externally generated menu video (.mp4, .mov, .webm, .mkv, .avi)
    to Godot-ready Ogg Theora (.ogv) for Proyecto Aurora's main menu.

.DESCRIPTION
    Outputs to assets/menu/video/cabina_menu_loop.ogv (or cabina_menu_intro.ogv)
    using libtheora parameters validated in Aurora (Editor.gd).
    Once converted, open/import the project in Godot and CabinaMenu.gd will
    automatically detect and play the external video while keeping all UI
    hotspots, glow, song card, and reduced-motion accessibility intact.

.EXAMPLE
    .\tools\import_menu_external_video.ps1 -InputVideo "C:\Videos\aurora_menu_loop.mp4"

.EXAMPLE
    .\tools\import_menu_external_video.ps1 -InputVideo "C:\Videos\aurora_intro.mp4" -Role intro
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputVideo,

    [ValidateSet("loop", "intro")]
    [string]$Role = "loop",

    [int]$MaxWidth = 1280,

    [int]$Fps = 30,

    [ValidateRange(1, 10)]
    [int]$Quality = 6
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputVideo)) {
    throw "Input video not found: $InputVideo"
}

function Resolve-FfmpegExe {
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    $wingetMatch = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") `
        -Filter "ffmpeg.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetMatch) {
        return $wingetMatch.FullName
    }
    throw "ffmpeg.exe was not found on PATH or in WinGet Packages."
}

$ffmpegExe = Resolve-FfmpegExe
$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot "assets\menu\video"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$fileName = if ($Role -eq "intro") { "cabina_menu_intro.ogv" } else { "cabina_menu_loop.ogv" }
$outputPath = Join-Path $outputDir $fileName

$vf = "fps=$Fps,scale=w='min($MaxWidth,iw)':h=-2:flags=lanczos,format=yuv420p"
$args = @(
    "-y",
    "-i", (Resolve-Path -LiteralPath $InputVideo).Path,
    "-an",
    "-vf", $vf,
    "-c:v", "libtheora",
    "-speed_level", "2",
    "-g", "$Fps",
    "-q:v", "$Quality",
    $outputPath
)

Write-Host "Converting '$InputVideo' -> '$outputPath' via libtheora..."
& $ffmpegExe @args
if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg exited with code $LASTEXITCODE"
}

Write-Host "Done. Next time Godot opens or imports the project, CabinaMenu will load $fileName automatically."
