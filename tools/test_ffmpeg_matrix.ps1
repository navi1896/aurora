#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$PackageRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$fixtureRoot = Join-Path $scriptRoot "ffmpeg_matrix_fixtures"

function Resolve-AuroraPackageRoot {
    param([string]$RequestedRoot)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $resolved = [IO.Path]::GetFullPath($RequestedRoot)
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            throw "No existe la carpeta del paquete indicada: $resolved"
        }
        return $resolved
    }

    $buildRoot = Join-Path $projectRoot "build"
    $candidates = @(
        Get-ChildItem -LiteralPath $buildRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                Test-Path -LiteralPath (
                    Join-Path $_.FullName "tools\ffmpeg\bin\ffmpeg.exe"
                ) -PathType Leaf
            } |
            Sort-Object LastWriteTimeUtc -Descending
    )
    if ($candidates.Count -eq 0) {
        throw (
            "No se encontró un paquete Aurora con FFmpeg en '$buildRoot'. " +
            "Genera primero el paquete o usa -PackageRoot."
        )
    }
    return $candidates[0].FullName
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine
    }
}

function Invoke-RequiredProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $result = Invoke-CapturedProcess -FilePath $FilePath -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw (
            "$Description falló con código $($result.ExitCode)." +
            [Environment]::NewLine + $result.Output
        )
    }
    return $result
}

function Get-MediaProbe {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$MediaPath
    )

    $probe = Invoke-RequiredProcess -FilePath $FfprobePath -Description (
        "La inspección de '$MediaPath'"
    ) -Arguments @(
        "-v", "error",
        "-show_entries",
        "format=format_name,duration:stream=codec_type,codec_name,width,height,pix_fmt,channels,avg_frame_rate,r_frame_rate",
        "-of", "json",
        $MediaPath
    )
    try {
        return $probe.Output | ConvertFrom-Json
    }
    catch {
        throw "ffprobe no devolvió JSON válido para '$MediaPath': $($probe.Output)"
    }
}

function Remove-VerifiedMatrixDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$ExpectedParent
    )

    $resolvedTarget = [IO.Path]::GetFullPath($Target).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $resolvedParent = [IO.Path]::GetFullPath($ExpectedParent).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $actualParent = [IO.Path]::GetDirectoryName($resolvedTarget).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $leafName = [IO.Path]::GetFileName($resolvedTarget)

    if (
        -not [string]::Equals(
            $actualParent,
            $resolvedParent,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        $leafName -notmatch "^AuroraFfmpegMatrix-[0-9a-f]{32}$"
    ) {
        throw "Se rechazó limpiar una ruta temporal no verificada: $resolvedTarget"
    }

    if (Test-Path -LiteralPath $resolvedTarget -PathType Container) {
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }
}

function Assert-SourceFixture {
    param(
        [Parameter(Mandatory = $true)][object]$Fixture,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$FfprobePath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        throw "Falta el fixture permanente: $SourcePath"
    }
    $actualHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    if (
        -not [string]::Equals(
            $actualHash,
            $Fixture.Sha256,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw (
            "El hash de '$($Fixture.FileName)' no coincide. " +
            "Esperado: $($Fixture.Sha256); actual: $actualHash"
        )
    }

    $probe = Get-MediaProbe -FfprobePath $FfprobePath -MediaPath $SourcePath
    $streams = @($probe.streams)
    $video = @($streams | Where-Object { $_.codec_type -eq "video" })
    $audio = @($streams | Where-Object { $_.codec_type -eq "audio" })
    if (
        $video.Count -ne 1 -or
        $video[0].codec_name -ne $Fixture.VideoCodec
    ) {
        throw (
            "'$($Fixture.FileName)' no contiene exactamente un flujo " +
            "$($Fixture.VideoCodec)."
        )
    }
    if (
        $Fixture.HasAudio -and (
            $audio.Count -ne 1 -or
            $audio[0].codec_name -ne $Fixture.AudioCodec
        )
    ) {
        throw (
            "'$($Fixture.FileName)' no contiene exactamente un flujo " +
            "$($Fixture.AudioCodec)."
        )
    }
    if (-not $Fixture.HasAudio -and $audio.Count -ne 0) {
        throw "'$($Fixture.FileName)' debía ser un fixture sin audio."
    }
}

function Assert-AuroraOutput {
    param(
        [Parameter(Mandatory = $true)][object]$Fixture,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$FfprobePath
    )

    $probe = Get-MediaProbe -FfprobePath $FfprobePath -MediaPath $OutputPath
    if ($probe.format.format_name -notmatch "(^|,)ogg(,|$)") {
        throw "La salida no utiliza el contenedor Ogg."
    }

    $streams = @($probe.streams)
    $video = @($streams | Where-Object { $_.codec_type -eq "video" })
    $audio = @($streams | Where-Object { $_.codec_type -eq "audio" })
    if ($video.Count -ne 1 -or $video[0].codec_name -ne "theora") {
        throw "La salida no contiene exactamente un flujo Theora."
    }
    if (
        [int]$video[0].width -gt 1280 -or
        [int]$video[0].height % 2 -ne 0 -or
        (
            $video[0].avg_frame_rate -ne "30/1" -and
            $video[0].r_frame_rate -ne "30/1"
        )
    ) {
        throw (
            "La salida no respeta tamaño par, ancho máximo o 30 FPS: " +
            "$($video[0] | ConvertTo-Json -Compress)"
        )
    }
    if (
        $Fixture.HasAudio -and (
            $audio.Count -ne 1 -or
            $audio[0].codec_name -ne "vorbis" -or
            [int]$audio[0].channels -ne 2
        )
    ) {
        throw "La salida no contiene exactamente un flujo Vorbis estéreo."
    }
    if (-not $Fixture.HasAudio -and $audio.Count -ne 0) {
        throw "La salida sin audio contiene un flujo de audio inesperado."
    }

    Invoke-RequiredProcess -FilePath $FfmpegPath `
        -Arguments @(
            "-hide_banner", "-loglevel", "error", "-xerror",
            "-i", $OutputPath,
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-f", "null", "-"
        ) `
        -Description "La decodificación completa de $($Fixture.Name)" |
        Out-Null
}

$fixtures = @(
    [PSCustomObject]@{
        Name = "MP4"
        FileName = "01-mp4-h264-aac.mp4"
        VideoCodec = "h264"
        AudioCodec = "aac"
        HasAudio = $true
        Sha256 = "A2F6049EA93BDC6A0C9633D72A8F9DF6A43569EEA45D76825692DAAF10B4067E"
    },
    [PSCustomObject]@{
        Name = "MOV"
        FileName = "02-mov-prores-pcm.mov"
        VideoCodec = "prores"
        AudioCodec = "pcm_s16le"
        HasAudio = $true
        Sha256 = "700C4ADF8EDC3F178D0CC6F7B0DEED478337AF3B34C0953F90693E0F79CE447A"
    },
    [PSCustomObject]@{
        Name = "M4V"
        FileName = "03-m4v-mpeg4-aac.m4v"
        VideoCodec = "mpeg4"
        AudioCodec = "aac"
        HasAudio = $true
        Sha256 = "04614205BD2B947FDEA621542DD5784ADF44E56326D865542E8C90CC8FD45A25"
    },
    [PSCustomObject]@{
        Name = "MKV"
        FileName = "04-mkv-h264-opus.mkv"
        VideoCodec = "h264"
        AudioCodec = "opus"
        HasAudio = $true
        Sha256 = "D347142AA44332E149AD98D22B7236962ACA14A7A9C6E2320E9993D986188CBA"
    },
    [PSCustomObject]@{
        Name = "WEBM"
        FileName = "05-webm-vp9-opus.webm"
        VideoCodec = "vp9"
        AudioCodec = "opus"
        HasAudio = $true
        Sha256 = "B45D7B3108D168890CA81E5435F57FA68712FBA2311B86006498B456ACDC420C"
    },
    [PSCustomObject]@{
        Name = "AVI"
        FileName = "06-avi-mjpeg-pcm.avi"
        VideoCodec = "mjpeg"
        AudioCodec = "pcm_s16le"
        HasAudio = $true
        Sha256 = "091BB6836248E6C015F8B55DDEC6C0730A1D325380A0ECE0B142F8F5ACF727E6"
    },
    [PSCustomObject]@{
        Name = "MP4 sin audio y Unicode"
        FileName = "07-sin-audio-español-日本語.mp4"
        VideoCodec = "mpeg4"
        AudioCodec = ""
        HasAudio = $false
        Sha256 = "0E77C60F436815E774F64CEBBE283906C855848DEDD424F49AC04CF2C4D57CA3"
    }
)

$resolvedPackageRoot = Resolve-AuroraPackageRoot -RequestedRoot $PackageRoot
$ffmpegPath = Join-Path $resolvedPackageRoot "tools\ffmpeg\bin\ffmpeg.exe"
$ffprobePath = Join-Path $resolvedPackageRoot "tools\ffmpeg\bin\ffprobe.exe"
foreach ($requiredTool in @($ffmpegPath, $ffprobePath)) {
    if (-not (Test-Path -LiteralPath $requiredTool -PathType Leaf)) {
        throw "El paquete no contiene la herramienta requerida: $requiredTool"
    }
}
if (-not (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    throw "No existe la carpeta de fixtures permanentes: $fixtureRoot"
}

$version = Invoke-RequiredProcess -FilePath $ffmpegPath `
    -Arguments @("-hide_banner", "-version") `
    -Description "La consulta de versión de FFmpeg"
$versionLine = ($version.Output -split "\r?\n" | Select-Object -First 1)

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempParent (
    "AuroraFfmpegMatrix-" + [Guid]::NewGuid().ToString("N")
)
$inputRoot = Join-Path $tempRoot "entradas con espacios"
$outputRoot = Join-Path $tempRoot "salidas con espacios"
$results = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()

Write-Output "Aurora // matriz de importación multimedia"
Write-Output "Paquete: $resolvedPackageRoot"
Write-Output "FFmpeg: $versionLine"
Write-Output "Fixtures: $fixtureRoot"
Write-Output ""

try {
    New-Item -ItemType Directory -Path $inputRoot, $outputRoot -Force | Out-Null

    foreach ($fixture in $fixtures) {
        $fixturePath = Join-Path $fixtureRoot $fixture.FileName
        $sourcePath = Join-Path $inputRoot $fixture.FileName
        $outputPath = Join-Path $outputRoot (
            [IO.Path]::GetFileNameWithoutExtension($fixture.FileName) + ".ogv"
        )

        try {
            Copy-Item -LiteralPath $fixturePath -Destination $sourcePath -Force
            Assert-SourceFixture `
                -Fixture $fixture `
                -SourcePath $sourcePath `
                -FfprobePath $ffprobePath

            # Debe permanecer sincronizado con Editor._build_ffmpeg_arguments().
            $auroraArguments = @(
                "-hide_banner",
                "-loglevel", "error",
                "-nostats",
                "-y",
                "-i", $sourcePath,
                "-map", "0:v:0",
                "-map", "0:a:0?",
                "-sn",
                "-dn",
                "-vf",
                "fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p",
                "-c:v", "libtheora",
                "-g", "30",
                "-q:v", "5",
                "-c:a", "libvorbis",
                "-q:a", "4",
                "-ac", "2",
                $outputPath
            )
            Invoke-RequiredProcess -FilePath $ffmpegPath `
                -Arguments $auroraArguments `
                -Description "La conversión Aurora de $($fixture.Name)" |
                Out-Null

            Assert-AuroraOutput `
                -Fixture $fixture `
                -OutputPath $outputPath `
                -FfmpegPath $ffmpegPath `
                -FfprobePath $ffprobePath

            $audioDescription = if ($fixture.HasAudio) {
                $fixture.AudioCodec
            }
            else {
                "sin audio"
            }
            $results.Add([PSCustomObject]@{
                Formato = $fixture.Name
                Entrada = "$($fixture.VideoCodec)/$audioDescription"
                Resultado = "OK"
            })
        }
        catch {
            $message = "$($fixture.Name): $($_.Exception.Message)"
            $failures.Add($message)
            $results.Add([PSCustomObject]@{
                Formato = $fixture.Name
                Entrada = "$($fixture.VideoCodec)/$($fixture.AudioCodec)"
                Resultado = "FALLO"
            })
        }
    }

    $corruptSource = Join-Path $inputRoot "08-corrupto.mp4"
    $corruptOutput = Join-Path $outputRoot "08-corrupto.ogv"
    [IO.File]::WriteAllBytes(
        $corruptSource,
        [Text.Encoding]::UTF8.GetBytes(
            "AURORA_FFMPEG_MATRIX_CORRUPT_FIXTURE`nEsto no es un contenedor multimedia."
        )
    )
    $corruptResult = Invoke-CapturedProcess -FilePath $ffmpegPath -Arguments @(
        "-hide_banner",
        "-loglevel", "error",
        "-nostats",
        "-y",
        "-i", $corruptSource,
        "-map", "0:v:0",
        "-map", "0:a:0?",
        "-sn",
        "-dn",
        "-vf",
        "fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p",
        "-c:v", "libtheora",
        "-g", "30",
        "-q:v", "5",
        "-c:a", "libvorbis",
        "-q:a", "4",
        "-ac", "2",
        $corruptOutput
    )
    if ($corruptResult.ExitCode -eq 0) {
        $failures.Add("Archivo corrupto: FFmpeg lo aceptó inesperadamente.")
        $results.Add([PSCustomObject]@{
            Formato = "MP4 corrupto"
            Entrada = "datos inválidos"
            Resultado = "FALLO"
        })
    }
    else {
        $results.Add([PSCustomObject]@{
            Formato = "MP4 corrupto"
            Entrada = "datos inválidos"
            Resultado = "RECHAZADO OK"
        })
    }

    Write-Output ($results | Format-Table -AutoSize | Out-String)

    if ($failures.Count -gt 0) {
        throw (
            "La matriz terminó con $($failures.Count) fallo(s):" +
            [Environment]::NewLine +
            (($failures | ForEach-Object { "  - $_" }) -join [Environment]::NewLine)
        )
    }

    Write-Output (
        "El FFmpeg empaquetado solo decodificó los fixtures; " +
        "no se usaron sus codificadores de entrada."
    )
    Write-Output "FFMPEG MATRIX PASSED"
    # Evita propagar al proceso invocador el código esperado del fixture corrupto.
    $global:LASTEXITCODE = 0
}
finally {
    Remove-VerifiedMatrixDirectory `
        -Target $tempRoot `
        -ExpectedParent $tempParent
}
