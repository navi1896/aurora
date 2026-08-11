#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$RootPath = (
        Join-Path $env:LOCALAPPDATA (
            "AuroraDevTools\btbn-ffmpeg-n8.1-win64-lgpl-20260729"
        )
    ),
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Pinned release snapshot selected only after Aurora's real-media visual gate
# passed. The dated BtbN release keeps the download immutable; the archive and
# both executables are additionally protected by fixed SHA-256 values.
$assetName = "ffmpeg-n8.1.2-31-g8c9502e9b0-win64-lgpl-8.1.zip"
$assetUri = (
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/" +
    "autobuild-2026-07-29-13-36/" +
    $assetName
)
$expectedArchiveSha256 = (
    "dc1caf47ae4fbbf33dcd39d30e7c7af2c63d417e872f0e948b5d68ae5a106794"
)
$expectedFfmpegSha256 = (
    "3f6613d4f28335e76b7c2bd6c27d2c28656e32c551f7236ff484ac7cf2ebd1c0"
)
$expectedFfprobeSha256 = (
    "e7bc681341cc545674e0644d864f52dad2a828ab99d4534f572cb95876b87740"
)
$expectedLicenseSha256 = (
    "da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768"
)
$expectedVersion = "n8.1.2-31-g8c9502e9b0-20260729"
$distributionDirectoryName = "ffmpeg-n8.1.2-31-g8c9502e9b0-win64-lgpl-8.1"

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
    $actual = (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw (
            "SHA-256 incorrecto para '$Path'. " +
            "Esperado: $ExpectedSha256; recibido: $actual."
        )
    }
}

function Reset-GeneratedDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$TargetDirectory,
        [Parameter(Mandatory)]
        [string]$AllowedRoot
    )

    $targetFull = [IO.Path]::GetFullPath($TargetDirectory).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $allowedFull = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $allowedPrefix = $allowedFull + [IO.Path]::DirectorySeparatorChar
    if (
        -not $targetFull.StartsWith(
            $allowedPrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        $targetFull -eq $allowedFull
    ) {
        throw "La limpieza salió de la carpeta de preparación: $targetFull"
    }
    if (Test-Path -LiteralPath $targetFull) {
        Remove-Item -LiteralPath $targetFull -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $targetFull -Force
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

function Get-CapabilityNames {
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
    $names = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
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
        [Collections.Generic.HashSet[string]]$Available,
        [Parameter(Mandatory)]
        [string[]]$Required,
        [Parameter(Mandatory)]
        [string]$Kind
    )

    foreach ($name in $Required) {
        if (-not $Available.Contains($name)) {
            throw "La distribución no contiene $Kind requerido: $name"
        }
    }
}

$allowedParent = [IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA "AuroraDevTools")
).TrimEnd([IO.Path]::DirectorySeparatorChar)
$root = [IO.Path]::GetFullPath($RootPath).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
)
$rootLeaf = Split-Path -Leaf $root
$allowedPrefix = $allowedParent + [IO.Path]::DirectorySeparatorChar
if (-not $root.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "La carpeta de trabajo debe estar dentro de '$allowedParent'."
}
if (
    $rootLeaf -notmatch (
        "^btbn-ffmpeg-n8\.1-win64-lgpl(?:-[A-Za-z0-9._-]+)?$"
    )
) {
    throw (
        "La carpeta debe comenzar con " +
        "'btbn-ffmpeg-n8.1-win64-lgpl' y usar solo un sufijo seguro."
    )
}

if ($Clean -and (Test-Path -LiteralPath $root)) {
    Remove-Item -LiteralPath $root -Recurse -Force
}
$downloadDirectory = Join-Path $root "download"
$extractDirectory = Join-Path $root "prepared-extract"
$packageDirectory = Join-Path $root "package"
$metadataDirectory = Join-Path $root "metadata"
foreach ($directory in @($root, $downloadDirectory)) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}

$archivePath = Join-Path $downloadDirectory $assetName
$partialPath = "$archivePath.partial"
if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
    Assert-FileHash `
        -Path $archivePath `
        -ExpectedSha256 $expectedArchiveSha256
    Write-Output "Archivo BtbN ya descargado y verificado."
}
else {
    try {
        Invoke-WebRequest -Uri $assetUri -OutFile $partialPath -UseBasicParsing
        Assert-FileHash `
            -Path $partialPath `
            -ExpectedSha256 $expectedArchiveSha256
        Move-Item -LiteralPath $partialPath -Destination $archivePath
        Write-Output "Archivo BtbN descargado y verificado."
    }
    finally {
        if (Test-Path -LiteralPath $partialPath -PathType Leaf) {
            Remove-Item -LiteralPath $partialPath -Force
        }
    }
}

Reset-GeneratedDirectory `
    -TargetDirectory $extractDirectory `
    -AllowedRoot $root
Expand-Archive `
    -LiteralPath $archivePath `
    -DestinationPath $extractDirectory `
    -Force

$distributionRoot = Join-Path $extractDirectory $distributionDirectoryName
$sourceBin = Join-Path $distributionRoot "bin"
$sourceFfmpeg = Join-Path $sourceBin "ffmpeg.exe"
$sourceFfprobe = Join-Path $sourceBin "ffprobe.exe"
$sourceLicense = Join-Path $distributionRoot "LICENSE.txt"
Assert-FileHash -Path $sourceFfmpeg -ExpectedSha256 $expectedFfmpegSha256
Assert-FileHash -Path $sourceFfprobe -ExpectedSha256 $expectedFfprobeSha256
Assert-FileHash -Path $sourceLicense -ExpectedSha256 $expectedLicenseSha256

$versionResult = Invoke-RequiredProcess `
    -FilePath $sourceFfmpeg `
    -Arguments @("-version") `
    -Description "La consulta de versión de FFmpeg"
$probeVersionResult = Invoke-RequiredProcess `
    -FilePath $sourceFfprobe `
    -Arguments @("-version") `
    -Description "La consulta de versión de ffprobe"
$licenseResult = Invoke-RequiredProcess `
    -FilePath $sourceFfmpeg `
    -Arguments @("-L") `
    -Description "La consulta de licencia de FFmpeg"
$configurationResult = Invoke-RequiredProcess `
    -FilePath $sourceFfmpeg `
    -Arguments @("-buildconf") `
    -Description "La consulta de configuración de FFmpeg"

$versionPattern = "^ffmpeg version " + [regex]::Escape($expectedVersion) + "(\s|$)"
$probeVersionPattern = "^ffprobe version " + [regex]::Escape($expectedVersion) + "(\s|$)"
$versionLine = [string]($versionResult.Lines | Select-Object -First 1)
$probeVersionLine = [string]($probeVersionResult.Lines | Select-Object -First 1)
if ($versionLine -notmatch $versionPattern) {
    throw "La versión de FFmpeg no coincide con el snapshot: $versionLine"
}
if ($probeVersionLine -notmatch $probeVersionPattern) {
    throw "La versión de ffprobe no coincide con el snapshot: $probeVersionLine"
}
$configurationText = $versionResult.Text + "`n" + $configurationResult.Text
foreach ($forbiddenFlag in @("--enable-gpl", "--enable-nonfree")) {
    if ($configurationText.Contains($forbiddenFlag)) {
        throw "La configuración LGPL contiene la opción prohibida $forbiddenFlag."
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
    if (-not $configurationText.Contains($requiredFlag)) {
        throw "La configuración no contiene la opción esperada $requiredFlag."
    }
}
if (
    $licenseResult.Text -notmatch "GNU Lesser General Public License" -or
    $licenseResult.Text -notmatch "version 3"
) {
    throw "El ejecutable no informó GNU LGPL versión 3 o posterior."
}

$encoders = Get-CapabilityNames -Executable $sourceFfmpeg -Option "-encoders"
$decoders = Get-CapabilityNames -Executable $sourceFfmpeg -Option "-decoders"
$filters = Get-CapabilityNames -Executable $sourceFfmpeg -Option "-filters"
$demuxers = Get-CapabilityNames -Executable $sourceFfmpeg -Option "-demuxers"
$muxers = Get-CapabilityNames -Executable $sourceFfmpeg -Option "-muxers"
Assert-Capabilities `
    -Available $encoders `
    -Required @("libtheora", "libvorbis", "pcm_s16le", "pcm_f32le") `
    -Kind "codificador"
Assert-Capabilities `
    -Available $decoders `
    -Required @(
        "h264", "hevc", "av1", "aac", "mp3", "opus", "vorbis", "vp8", "vp9"
    ) `
    -Kind "decodificador"
Assert-Capabilities `
    -Available $filters `
    -Required @(
        "aresample", "format", "fps", "scale", "setpts", "split", "ssim", "psnr"
    ) `
    -Kind "filtro"
Assert-Capabilities `
    -Available $demuxers `
    -Required @("mov", "avi", "matroska") `
    -Kind "demuxer"
Assert-Capabilities -Available $muxers -Required @("ogg", "f32le") -Kind "muxer"

$unexpectedDlls = @(
    Get-ChildItem -LiteralPath $sourceBin -Filter "*.dll" -File `
        -ErrorAction SilentlyContinue
)
if ($unexpectedDlls.Count -ne 0) {
    throw "El archivo BtbN contiene DLL de FFmpeg inesperadas."
}

Reset-GeneratedDirectory `
    -TargetDirectory $packageDirectory `
    -AllowedRoot $root
Reset-GeneratedDirectory `
    -TargetDirectory $metadataDirectory `
    -AllowedRoot $root
$packageBin = Join-Path $packageDirectory "bin"
$null = New-Item -ItemType Directory -Path $packageBin -Force
Copy-Item -LiteralPath $sourceFfmpeg -Destination (
    Join-Path $packageBin "ffmpeg.exe"
) -Force
Copy-Item -LiteralPath $sourceFfprobe -Destination (
    Join-Path $packageBin "ffprobe.exe"
) -Force
Copy-Item -LiteralPath $sourceLicense -Destination (
    Join-Path $packageDirectory "LICENSE.txt"
) -Force

Set-Content -LiteralPath (
    Join-Path $metadataDirectory "BUILD_CONFIGURATION.txt"
) -Encoding UTF8 -Value @(
    "Pinned BtbN FFmpeg snapshot used by Aurora",
    "==========================================",
    "",
    "Archive: $assetName",
    "Archive URL: $assetUri",
    "Archive SHA-256: $expectedArchiveSha256",
    "BtbN build scripts commit:",
    "https://github.com/BtbN/FFmpeg-Builds/tree/8c736b2d6fe5da2a10a8896d01e53bfb0ca4f665",
    "FFmpeg source commit:",
    "https://github.com/FFmpeg/FFmpeg/commit/8c9502e9b048e21e1cae96477e338ac0635645ba",
    "",
    $versionResult.Text,
    "",
    $probeVersionResult.Text,
    "",
    "Build configuration",
    "-------------------",
    $configurationResult.Text,
    "",
    "License report",
    "--------------",
    $licenseResult.Text
)

$capabilityReport = @(
    "Aurora-required capabilities validated on $expectedVersion",
    "==========================================================",
    "",
    "Encoders: libtheora, libvorbis, pcm_s16le, pcm_f32le",
    "Decoders: h264, hevc, av1, aac, mp3, opus, vorbis, vp8, vp9",
    "Filters: aresample, format, fps, scale, setpts, split, ssim, psnr",
    "Demuxers: mov (MP4/MOV/M4V), avi, matroska (MKV/WebM)",
    "Muxers: ogg, f32le"
)
Set-Content -LiteralPath (
    Join-Path $metadataDirectory "AURORA_CAPABILITIES.txt"
) -Encoding UTF8 -Value $capabilityReport

Set-Content -LiteralPath (
    Join-Path $metadataDirectory "HASHES-SHA256.txt"
) -Encoding UTF8 -Value @(
    "$expectedArchiveSha256  download/$assetName",
    "$expectedFfmpegSha256  package/bin/ffmpeg.exe",
    "$expectedFfprobeSha256  package/bin/ffprobe.exe",
    "$expectedLicenseSha256  package/LICENSE.txt"
)

Write-Output "FFmpeg BtbN preparado: $versionLine"
Write-Output "ffprobe BtbN preparado: $probeVersionLine"
Write-Output "Licencia informada: GNU LGPL v3 o posterior"
Write-Output "Raíz validada: $root"
