param(
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$temporaryProfile = Join-Path $env:TEMP ("AuroraSmoke-" + [guid]::NewGuid().ToString("N"))

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $knownCandidates = @(
        $env:GODOT_EXE,
        "C:\Users\ivana\Downloads\Godot_v4.8-dev2_win64.exe\Godot_v4.8-dev2_win64_console.exe"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) }

    if ($knownCandidates.Count -gt 0) {
        $GodotExe = $knownCandidates[0]
    } else {
        $godotCommand = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $godotCommand) {
            $GodotExe = $godotCommand.Source
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExe) -or -not (Test-Path -LiteralPath $GodotExe)) {
    throw "No se encontró Godot. Usa -GodotExe con la ruta al ejecutable de consola."
}

New-Item -ItemType Directory -Path $temporaryProfile -Force | Out-Null
$previousAppData = $env:APPDATA

try {
    $env:APPDATA = $temporaryProfile
    & $GodotExe --headless --path $projectRoot --script res://tools/smoke_test.gd
    exit $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
}
