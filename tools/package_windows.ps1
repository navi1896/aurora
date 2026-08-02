#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$BuildDirectory = "",
    [string]$FfmpegBuildRoot = (
        Join-Path $env:LOCALAPPDATA (
            "AuroraDevTools\btbn-ffmpeg-n8.1-win64-lgpl-20260729"
        )
    ),
    [switch]$CreateZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Reset-GeneratedDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$TargetDirectory,
        [Parameter(Mandatory)]
        [string]$AllowedRoot
    )

    $targetFull = [System.IO.Path]::GetFullPath($TargetDirectory).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $allowedFull = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $allowedPrefix = $allowedFull + [System.IO.Path]::DirectorySeparatorChar
    if (
        -not $targetFull.StartsWith(
            $allowedPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $targetFull -eq $allowedFull
    ) {
        throw "La limpieza de empaquetado salió de su carpeta generada: $targetFull"
    }
    if (Test-Path -LiteralPath $targetFull) {
        Remove-Item -LiteralPath $targetFull -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $targetFull -Force
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$ExpectedSha256
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta el archivo requerido: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw (
            "El SHA-256 no coincide para '$Path'. " +
            "Esperado: $ExpectedSha256; recibido: $actual."
        )
    }
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments 2>&1)
    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Lines = @($output | ForEach-Object { "$_" })
        Text = ($output | ForEach-Object { "$_" }) -join [Environment]::NewLine
    }
}

function Invoke-RequiredProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$Description
    )

    $result = Invoke-CapturedProcess -FilePath $FilePath -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw (
            "$Description falló con código $($result.ExitCode)." +
            [Environment]::NewLine + $result.Text
        )
    }
    return $result
}

function Get-FfmpegCapabilityNames {
    param(
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [ValidateSet("-encoders", "-decoders", "-filters", "-demuxers", "-muxers")]
        [string]$Option
    )

    $result = Invoke-RequiredProcess `
        -FilePath $Executable `
        -Arguments @("-hide_banner", $Option) `
        -Description "La consulta de capacidades $Option"

    $pattern = switch ($Option) {
        "-encoders" { "^\s*\S{6}\s+(?<Names>\S+)" }
        "-decoders" { "^\s*\S{6}\s+(?<Names>\S+)" }
        "-filters" { "^\s*[TSC\.]{2,3}\s+(?<Names>\S+)" }
        "-demuxers" { "^\s*D\s+(?<Names>\S+)" }
        "-muxers" { "^\s*E\s+(?<Names>\S+)" }
    }

    $names = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($line in $result.Lines) {
        $match = [regex]::Match($line, $pattern)
        if (-not $match.Success) {
            continue
        }
        foreach ($name in $match.Groups["Names"].Value.Split(",")) {
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $null = $names.Add($name)
            }
        }
    }
    Write-Output -NoEnumerate $names
}

function Assert-Capabilities {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.HashSet[string]]$Available,
        [Parameter(Mandatory)]
        [string[]]$Required,
        [Parameter(Mandatory)]
        [string]$Kind
    )

    foreach ($name in $Required) {
        if (-not $Available.Contains($name)) {
            throw "La compilación no contiene $Kind requerido: $name"
        }
    }
}

$projectRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$buildParent = [System.IO.Path]::GetFullPath(
    (Join-Path $projectRoot "build")
).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $buildParent "Aurora-v1.0.0-Windows"
}
if (-not (Test-Path -LiteralPath $BuildDirectory -PathType Container)) {
    throw "No existe la carpeta de exportación: $BuildDirectory"
}

$buildRoot = [System.IO.Path]::GetFullPath($BuildDirectory).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
)
$buildPrefix = $buildParent + [System.IO.Path]::DirectorySeparatorChar
if (
    -not $buildRoot.StartsWith(
        $buildPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or
    [System.IO.Path]::GetFileName($buildRoot) -ne "Aurora-v1.0.0-Windows"
) {
    throw "El paquete oficial debe permanecer en '$buildParent\Aurora-v1.0.0-Windows'."
}

$auroraExecutable = Join-Path $buildRoot "Aurora.exe"
$auroraPack = Join-Path $buildRoot "Aurora.pck"
foreach ($requiredExport in @($auroraExecutable, $auroraPack)) {
    if (-not (Test-Path -LiteralPath $requiredExport -PathType Leaf)) {
        throw "Falta el archivo exportado: $requiredExport"
    }
}

# El empaquetado se ejecuta sobre una exportación limpia. En una repetición se
# aceptan únicamente los archivos que este mismo script genera.
$allowedExistingFiles = @(
    "Aurora.exe",
    "Aurora.pck",
    "CHECKSUMS-SHA256.txt",
    "LEEME.txt",
    "LICENCIAS.txt",
    "PUBLICACION.txt"
)
$allowedExistingDirectories = @("licenses", "tools")
foreach ($entry in Get-ChildItem -LiteralPath $buildRoot -Force) {
    if (
        $entry.PSIsContainer -and
        $entry.Name -notin $allowedExistingDirectories
    ) {
        throw "La exportación contiene una carpeta inesperada: $($entry.FullName)"
    }
    if (
        -not $entry.PSIsContainer -and
        $entry.Name -notin $allowedExistingFiles
    ) {
        throw "La exportación contiene un archivo inesperado: $($entry.FullName)"
    }
}

$ffmpegBuildRoot = [System.IO.Path]::GetFullPath($FfmpegBuildRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
)
$expectedToolParent = [System.IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA "AuroraDevTools")
).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$expectedToolPrefix = $expectedToolParent + [System.IO.Path]::DirectorySeparatorChar
$ffmpegBuildLeaf = [System.IO.Path]::GetFileName($ffmpegBuildRoot)
if (
    -not $ffmpegBuildRoot.StartsWith(
        $expectedToolPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    ) -or
    $ffmpegBuildLeaf -notmatch (
        "^btbn-ffmpeg-n8\.1-win64-lgpl(?:-[A-Za-z0-9._-]+)?$"
    )
) {
    throw "La distribución BtbN LGPL fijada no está en la ruta esperada."
}

$ffmpegSourceExe = Join-Path $ffmpegBuildRoot "package\bin\ffmpeg.exe"
$ffprobeSourceExe = Join-Path $ffmpegBuildRoot "package\bin\ffprobe.exe"
$ffmpegLicense = Join-Path $ffmpegBuildRoot "package\LICENSE.txt"
$ffmpegArchive = Join-Path (
    $ffmpegBuildRoot
) "download\ffmpeg-n8.1-latest-win64-lgpl-8.1.zip"
$godotCopyright = Join-Path $projectRoot "legal\GODOT_COPYRIGHT.txt"

$verifiedFiles = @(
    @{
        Path = $ffmpegArchive
        Sha256 = "fce9c9c569425ec509bc90b361119ece81ee11fb7b557552c52187b497dba982"
    },
    @{
        Path = $ffmpegSourceExe
        Sha256 = "3f6613d4f28335e76b7c2bd6c27d2c28656e32c551f7236ff484ac7cf2ebd1c0"
    },
    @{
        Path = $ffprobeSourceExe
        Sha256 = "e7bc681341cc545674e0644d864f52dad2a828ab99d4534f572cb95876b87740"
    },
    @{
        Path = $ffmpegLicense
        Sha256 = "da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768"
    },
    @{
        Path = $godotCopyright
        Sha256 = "3e54b8b4e939bd8b42616776056bd94b3735c4ed5d39ae00aedd275b853d8b56"
    }
)
foreach ($file in $verifiedFiles) {
    Assert-FileHash -Path $file.Path -ExpectedSha256 $file.Sha256
}

$unexpectedSourceDlls = @(
    Get-ChildItem -LiteralPath (
        Join-Path $ffmpegBuildRoot "package\bin"
    ) -Filter "*.dll" -File -ErrorAction SilentlyContinue
)
if ($unexpectedSourceDlls.Count -gt 0) {
    throw "La compilación mínima contiene DLL inesperadas."
}

$versionResult = Invoke-RequiredProcess `
    -FilePath $ffmpegSourceExe `
    -Arguments @("-version") `
    -Description "La consulta de versión de FFmpeg"
$probeVersionResult = Invoke-RequiredProcess `
    -FilePath $ffprobeSourceExe `
    -Arguments @("-version") `
    -Description "La consulta de versión de ffprobe"
$licenseResult = Invoke-RequiredProcess `
    -FilePath $ffmpegSourceExe `
    -Arguments @("-L") `
    -Description "La consulta de licencia de FFmpeg"
$buildConfiguration = Invoke-RequiredProcess `
    -FilePath $ffmpegSourceExe `
    -Arguments @("-buildconf") `
    -Description "La consulta de configuración de FFmpeg"

$ffmpegVersionLine = [string]($versionResult.Lines | Select-Object -First 1)
$ffprobeVersionLine = [string]($probeVersionResult.Lines | Select-Object -First 1)
$versionText = $versionResult.Text
if (
    $ffmpegVersionLine -notmatch (
        "^ffmpeg version n8\.1\.2-31-g8c9502e9b0-20260729(\s|$)"
    )
) {
    throw "La versión de FFmpeg no es la validada: $ffmpegVersionLine"
}
if (
    $ffprobeVersionLine -notmatch (
        "^ffprobe version n8\.1\.2-31-g8c9502e9b0-20260729(\s|$)"
    )
) {
    throw "La versión de ffprobe no es la validada: $ffprobeVersionLine"
}
foreach ($forbiddenFlag in @("--enable-gpl", "--enable-nonfree")) {
    if ($versionText.Contains($forbiddenFlag)) {
        throw "La configuración contiene una opción prohibida: $forbiddenFlag"
    }
}
foreach ($requiredFlag in @(
    "--enable-version3",
    "--disable-libx264",
    "--disable-libx265",
    "--disable-libfdk-aac",
    "--enable-libtheora",
    "--enable-libvorbis"
)) {
    if (-not $versionText.Contains($requiredFlag)) {
        throw "La configuración no contiene la opción requerida: $requiredFlag"
    }
}
if (
    $licenseResult.Text -notmatch "GNU Lesser General Public" -or
    $licenseResult.Text -notmatch "version 3"
) {
    throw "FFmpeg no informó la licencia LGPL 3 o posterior esperada."
}

$normalizedProfile = [System.IO.Path]::GetFullPath($env:USERPROFILE).Replace("\", "/")
$reportedBuildText = ($versionResult.Text + "`n" + $buildConfiguration.Text).Replace("\", "/")
if ($reportedBuildText.Contains($normalizedProfile)) {
    throw "La configuración de FFmpeg expone la ruta personal del compilador."
}

$encoders = Get-FfmpegCapabilityNames -Executable $ffmpegSourceExe -Option "-encoders"
$decoders = Get-FfmpegCapabilityNames -Executable $ffmpegSourceExe -Option "-decoders"
$filters = Get-FfmpegCapabilityNames -Executable $ffmpegSourceExe -Option "-filters"
$demuxers = Get-FfmpegCapabilityNames -Executable $ffmpegSourceExe -Option "-demuxers"
$muxers = Get-FfmpegCapabilityNames -Executable $ffmpegSourceExe -Option "-muxers"
Assert-Capabilities `
    -Available $encoders `
    -Required @(
        "libtheora", "libvorbis", "pcm_s16le", "pcm_f32le", "wrapped_avframe"
    ) `
    -Kind "codificador"
Assert-Capabilities `
    -Available $decoders `
    -Required @("h264", "hevc", "av1", "aac", "mp3", "opus", "vp8", "vp9") `
    -Kind "decodificador"
Assert-Capabilities `
    -Available $filters `
    -Required @(
        "aresample", "fps", "scale", "format", "setpts", "split", "ssim", "psnr"
    ) `
    -Kind "filtro"
Assert-Capabilities `
    -Available $demuxers `
    -Required @("mov", "avi", "matroska", "m4v") `
    -Kind "demuxer"
Assert-Capabilities -Available $muxers -Required @("ogg", "f32le") -Kind "muxer"

$ffmpegTargetRoot = Join-Path $buildRoot "tools\ffmpeg"
$ffmpegTargetBin = Join-Path $ffmpegTargetRoot "bin"
$ffmpegLicenseTarget = Join-Path $buildRoot "licenses\FFmpeg"
$godotLicenseTarget = Join-Path $buildRoot "licenses\Godot"
$fontLicenseTarget = Join-Path $buildRoot "licenses\PressStart2P"
foreach ($generatedDirectory in @(
    $ffmpegTargetRoot,
    $ffmpegLicenseTarget,
    $godotLicenseTarget,
    $fontLicenseTarget
)) {
    Reset-GeneratedDirectory `
        -TargetDirectory $generatedDirectory `
        -AllowedRoot $buildRoot
}

$ffmpegSourceTarget = Join-Path $ffmpegLicenseTarget "source"
foreach ($directory in @($ffmpegTargetBin, $ffmpegSourceTarget)) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}

Copy-Item -LiteralPath $ffmpegSourceExe -Destination (
    Join-Path $ffmpegTargetBin "ffmpeg.exe"
) -Force
Copy-Item -LiteralPath $ffprobeSourceExe -Destination (
    Join-Path $ffmpegTargetBin "ffprobe.exe"
) -Force
Copy-Item -LiteralPath $ffmpegLicense -Destination (
    Join-Path $ffmpegLicenseTarget "LICENSE.txt"
) -Force
Copy-Item -LiteralPath (
    Join-Path $projectRoot "legal\FFMPEG_SOURCE_AND_BUILD.txt"
) -Destination (Join-Path $ffmpegLicenseTarget "SOURCE_AND_BUILD.txt") -Force
Copy-Item -LiteralPath (
    Join-Path $projectRoot "legal\FFMPEG_EXTERNAL_LIBRARIES.txt"
) -Destination (Join-Path $ffmpegLicenseTarget "EXTERNAL_LIBRARIES.txt") -Force
Copy-Item -LiteralPath (
    Join-Path $projectRoot "legal\FFMPEG_RUNTIME_DEPENDENCIES.txt"
) -Destination (
    Join-Path $ffmpegLicenseTarget "RUNTIME_DEPENDENCIES.txt"
) -Force
Copy-Item -LiteralPath (
    Join-Path $projectRoot "tools\prepare_ffmpeg_btbn.ps1"
) -Destination (
    Join-Path $ffmpegSourceTarget "prepare_ffmpeg_btbn.ps1"
) -Force

Copy-Item -LiteralPath (Join-Path $projectRoot "legal\GODOT_LICENSE.txt") `
    -Destination (Join-Path $godotLicenseTarget "GODOT_LICENSE.txt") -Force
Copy-Item -LiteralPath $godotCopyright `
    -Destination (Join-Path $godotLicenseTarget "GODOT_COPYRIGHT.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "assets\menu\fonts\OFL.txt") `
    -Destination (Join-Path $fontLicenseTarget "OFL.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "legal\THIRD_PARTY_NOTICES.txt") `
    -Destination (Join-Path $buildRoot "LICENCIAS.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "legal\LEEME_DISTRIBUCION.txt") `
    -Destination (Join-Path $buildRoot "LEEME.txt") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "legal\PUBLICACION.txt") `
    -Destination (Join-Path $buildRoot "PUBLICACION.txt") -Force

$bundledFfmpeg = Join-Path $ffmpegTargetBin "ffmpeg.exe"
$bundledFfprobe = Join-Path $ffmpegTargetBin "ffprobe.exe"
$unexpectedRuntimeFiles = @(
    Get-ChildItem -LiteralPath $ffmpegTargetBin -File |
        Where-Object { $_.Name -notin @("ffmpeg.exe", "ffprobe.exe") }
)
if ($unexpectedRuntimeFiles.Count -ne 0) {
    throw "Se copiaron archivos de ejecución inesperados junto a FFmpeg."
}

$buildConfigurationPath = Join-Path $ffmpegLicenseTarget "BUILD_CONFIGURATION.txt"
Set-Content -LiteralPath $buildConfigurationPath -Encoding UTF8 -Value @(
    "FFmpeg version, configuration and license reported by the bundled executable",
    "=============================================================================",
    "",
    $versionResult.Text,
    "",
    $probeVersionResult.Text,
    "",
    "Build configuration",
    "-------------------",
    $buildConfiguration.Text,
    "",
    "License report",
    "--------------",
    $licenseResult.Text
)

Set-Content -LiteralPath (
    Join-Path $ffmpegLicenseTarget "AURORA_CAPABILITIES.txt"
) -Encoding UTF8 -Value @(
    "Aurora-required capabilities validated on the bundled FFmpeg",
    "============================================================",
    "",
    "Encoders: libtheora, libvorbis, pcm_s16le, pcm_f32le",
    "Decoders: h264, hevc, av1, aac, mp3, opus, vorbis, vp8, vp9",
    "Filters: aresample, format, fps, scale, setpts, split, ssim, psnr",
    "Demuxers: mov (MP4/MOV/M4V), avi, matroska (MKV/WebM)",
    "Muxers: ogg, f32le"
)
Set-Content -LiteralPath (
    Join-Path $ffmpegLicenseTarget "UPSTREAM_HASHES-SHA256.txt"
) -Encoding UTF8 -Value @(
    (
        "fce9c9c569425ec509bc90b361119ece81ee11fb7b557552c52187b497dba982" +
        "  ffmpeg-n8.1-latest-win64-lgpl-8.1.zip"
    ),
    (
        "3f6613d4f28335e76b7c2bd6c27d2c28656e32c551f7236ff484ac7cf2ebd1c0" +
        "  tools/ffmpeg/bin/ffmpeg.exe"
    ),
    (
        "e7bc681341cc545674e0644d864f52dad2a828ab99d4534f572cb95876b87740" +
        "  tools/ffmpeg/bin/ffprobe.exe"
    ),
    (
        "da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768" +
        "  licenses/FFmpeg/LICENSE.txt"
    )
)

$smokeVideo = Join-Path $ffmpegTargetRoot "aurora-ffmpeg-smoke.ogv"
try {
    Invoke-RequiredProcess `
        -FilePath $bundledFfmpeg `
        -Arguments @(
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi",
            "-i", "testsrc2=size=320x180:rate=30:duration=1",
            "-f", "lavfi",
            "-i", "sine=frequency=440:sample_rate=48000:duration=1",
            "-map", "0:v:0",
            "-map", "1:a:0?",
            "-vf",
            "fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p",
            "-c:v", "libtheora",
            "-g", "30",
            "-q:v", "5",
            "-c:a", "libvorbis",
            "-q:a", "4",
            "-ac", "2",
            $smokeVideo
        ) `
        -Description "La conversión sintética Theora/Vorbis" |
        Out-Null

    Invoke-RequiredProcess `
        -FilePath $bundledFfmpeg `
        -Arguments @(
            "-hide_banner", "-loglevel", "error", "-xerror",
            "-i", $smokeVideo,
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-f", "null", "-"
        ) `
        -Description "La decodificación completa del OGV sintético" |
        Out-Null
}
finally {
    if (Test-Path -LiteralPath $smokeVideo -PathType Leaf) {
        Remove-Item -LiteralPath $smokeVideo -Force
    }
}

$matrixScript = Join-Path $projectRoot "tools\test_ffmpeg_matrix.ps1"
if (-not (Test-Path -LiteralPath $matrixScript -PathType Leaf)) {
    throw "Falta la matriz de importación: $matrixScript"
}
$matrixOutput = @(& $matrixScript -PackageRoot $buildRoot 2>&1)
$matrixExitCode = $LASTEXITCODE
$matrixText = ($matrixOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine
if ($matrixExitCode -ne 0 -or $matrixText -notmatch "FFMPEG MATRIX PASSED") {
    throw "La matriz de importación falló.$([Environment]::NewLine)$matrixText"
}

$checksumPath = Join-Path $buildRoot "CHECKSUMS-SHA256.txt"
$checksumLines = Get-ChildItem -LiteralPath $buildRoot -File -Recurse |
    Where-Object { $_.FullName -ne $checksumPath } |
    Sort-Object FullName |
    ForEach-Object {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
        $relativePath = [System.IO.Path]::GetRelativePath(
            $buildRoot,
            $_.FullName
        ).Replace("\", "/")
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $relativePath
    }
Set-Content -LiteralPath $checksumPath -Value $checksumLines -Encoding UTF8

Write-Output "FFmpeg incluido: $ffmpegVersionLine"
Write-Output "ffprobe incluido: $ffprobeVersionLine"
Write-Output "Conversión Theora/Vorbis interna: OK"
Write-Output "Matriz MP4/MOV/M4V/MKV/WebM/AVI: OK"
Write-Output "Paquete preparado: $buildRoot"

if ($CreateZip) {
    $zipPath = "$buildRoot.zip"
    $zipFull = [System.IO.Path]::GetFullPath($zipPath)
    if (
        [System.IO.Path]::GetDirectoryName($zipFull) -ne $buildParent -or
        [System.IO.Path]::GetFileName($zipFull) -ne "Aurora-v1.0.0-Windows.zip"
    ) {
        throw "La ruta del ZIP final no es la esperada: $zipFull"
    }
    if (Test-Path -LiteralPath $zipFull -PathType Leaf) {
        Remove-Item -LiteralPath $zipFull -Force
    }
    Compress-Archive `
        -Path (Join-Path $buildRoot "*") `
        -DestinationPath $zipFull `
        -CompressionLevel Optimal
    $zipHash = (Get-FileHash -LiteralPath $zipFull -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Output "ZIP actualizado: $zipFull"
    Write-Output "SHA-256 del ZIP: $zipHash"
}
