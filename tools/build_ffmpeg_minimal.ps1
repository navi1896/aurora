#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$RootPath = (Join-Path $env:LOCALAPPDATA "AuroraDevTools\ffmpeg-minimal-repro"),
    [ValidateRange(1, 64)]
    [int]$Jobs = [Math]::Max(1, [Math]::Min(8, [Environment]::ProcessorCount)),
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# This recipe intentionally builds in an isolated, portable directory. It does
# not install software and never changes the user or machine PATH.
$sourceDateEpoch = "1781983993"
$expectedLeafPattern = "^ffmpeg-minimal-repro(?:-[A-Za-z0-9._-]+)?$"
$allowedParent = [System.IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA "AuroraDevTools")
).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
)
$rootLeaf = Split-Path -Leaf $root
$allowedPrefix = $allowedParent + [System.IO.Path]::DirectorySeparatorChar

if (-not $root.StartsWith($allowedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "La carpeta de trabajo debe estar dentro de '$allowedParent'."
}
if ($rootLeaf -notmatch $expectedLeafPattern) {
    throw "La carpeta final debe llamarse 'ffmpeg-minimal-repro' o usar ese nombre con un sufijo seguro."
}
if ($root -match "\s") {
    throw "La ruta de compilación no puede contener espacios: '$root'."
}

if ($Clean -and (Test-Path -LiteralPath $root)) {
    # The target has already been constrained to a narrow AuroraDevTools child.
    Remove-Item -LiteralPath $root -Recurse -Force
}
elseif (Test-Path -LiteralPath $root) {
    $existingEntry = Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop |
        Select-Object -First 1
    if ($null -ne $existingEntry) {
        throw "La carpeta '$root' ya contiene archivos. Usa -Clean explícitamente o elige una carpeta nueva."
    }
}

$downloads = Join-Path $root "downloads"
$sources = Join-Path $root "src"
$toolchain = Join-Path $root "toolchain"
$metadata = Join-Path $root "metadata"

foreach ($directory in @($root, $downloads, $sources, $toolchain, $metadata)) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}

$artifacts = @(
    @{
        Name = "w64devkit-x64-2.8.0.7z.exe"
        Uri = "https://github.com/skeeto/w64devkit/releases/download/v2.8.0/w64devkit-x64-2.8.0.7z.exe"
        Sha256 = "6252bf34fe2231a55ac7f03d482b36d2c7c58697990551bba508102cfb3f342e"
    },
    @{
        Name = "ffmpeg-6.1.6.tar.xz"
        Uri = "https://ffmpeg.org/releases/ffmpeg-6.1.6.tar.xz"
        Sha256 = "d4fcb164028dd3beee5d92c0ac72e46aac6973c75ea12dc14de07bf8f407370a"
    },
    @{
        Name = "ffmpeg-6.1.6.tar.xz.asc"
        Uri = "https://ffmpeg.org/releases/ffmpeg-6.1.6.tar.xz.asc"
        Sha256 = "d723aad27d00de29dc98a8718002c05cb4293eb2f6240baac70cf066a5607b88"
    },
    @{
        Name = "ffmpeg-devel.asc"
        Uri = "https://ffmpeg.org/ffmpeg-devel.asc"
        Sha256 = "397b3becedcd5a98769967ff1ff8501ddc89f8368b8f766e4701377d7dbaabe5"
    },
    @{
        Name = "libogg-1.3.6.tar.xz"
        Uri = "https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz"
        Sha256 = "5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061"
    },
    @{
        Name = "libvorbis-1.3.7.tar.xz"
        Uri = "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz"
        Sha256 = "b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b"
    },
    @{
        Name = "libtheora-1.2.0.tar.gz"
        Uri = "https://downloads.xiph.org/releases/theora/libtheora-1.2.0.tar.gz"
        Sha256 = "279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e"
    },
    @{
        Name = "COPYING.RUNTIME-GCC-16.1.0.txt"
        Uri = "https://gcc.gnu.org/git/?p=gcc.git;a=blob_plain;f=COPYING.RUNTIME;hb=releases/gcc-16.1.0"
        Sha256 = "9d6b43ce4d8de0c878bf16b54d8e7a10d9bd42b75178153e3af6a815bdc90f74"
    }
)

function Assert-FileHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$ExpectedSha256
    )

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "SHA-256 incorrecto para '$Path'. Esperado: $ExpectedSha256; recibido: $actual."
    }
}

function Get-VerifiedDownload {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Artifact
    )

    $destination = Join-Path $downloads $Artifact.Name
    $partial = "$destination.partial"

    if (Test-Path -LiteralPath $destination) {
        Assert-FileHash -Path $destination -ExpectedSha256 $Artifact.Sha256
        Write-Host "Verificado: $($Artifact.Name)"
        return
    }

    try {
        Invoke-WebRequest -Uri $Artifact.Uri -OutFile $partial -UseBasicParsing
        Assert-FileHash -Path $partial -ExpectedSha256 $Artifact.Sha256
        Move-Item -LiteralPath $partial -Destination $destination
        Write-Host "Descargado y verificado: $($Artifact.Name)"
    }
    finally {
        # Only a transient file created by this invocation may be removed here.
        if (Test-Path -LiteralPath $partial) {
            Remove-Item -LiteralPath $partial -Force
        }
    }
}

foreach ($artifact in $artifacts) {
    Get-VerifiedDownload -Artifact $artifact
}

$gitCommand = Get-Command git.exe -ErrorAction Stop
$gitBinDirectory = Split-Path -Parent $gitCommand.Source
$gitUsrSource = [System.IO.Path]::GetFullPath(
    (Join-Path $gitBinDirectory "..\usr")
)
if (-not (Test-Path -LiteralPath (Join-Path $gitUsrSource "bin\bash.exe"))) {
    throw "No se encontró Git Bash junto a '$($gitCommand.Source)'. Instala Git for Windows o corrige su instalación."
}

# Copy the complete Git usr tree so bash and all of its coreutils/DLLs resolve
# relative to the space-free local toolchain instead of C:\Program Files\Git.
$gitUsr = Join-Path $toolchain "git-usr"
$null = New-Item -ItemType Directory -Path $gitUsr -Force
& robocopy.exe $gitUsrSource $gitUsr /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
$robocopyExitCode = $LASTEXITCODE
if ($robocopyExitCode -gt 7) {
    throw "No se pudo preparar la copia local de Git Bash (robocopy: $robocopyExitCode)."
}

$w64Archive = Join-Path $downloads "w64devkit-x64-2.8.0.7z.exe"
& $w64Archive -y "-o$toolchain"
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo extraer w64devkit (código $LASTEXITCODE)."
}

$bash = Join-Path $gitUsr "bin\bash.exe"
$gcc = Join-Path $toolchain "w64devkit\bin\gcc.exe"
$make = Join-Path $toolchain "w64devkit\bin\make.exe"
foreach ($requiredTool in @($bash, $gcc, $make)) {
    if (-not (Test-Path -LiteralPath $requiredTool)) {
        throw "Herramienta portátil ausente después de extraer/copiar: '$requiredTool'."
    }
}

function ConvertTo-MsysPath {
    param(
        [Parameter(Mandatory)]
        [string]$WindowsPath
    )

    $fullPath = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($fullPath -notmatch "^(?<Drive>[A-Za-z]):\\(?<Rest>.*)$") {
        throw "Solo se admiten rutas locales con letra de unidad: '$fullPath'."
    }
    return "/$($Matches.Drive.ToLowerInvariant())/$($Matches.Rest.Replace('\', '/'))"
}

$rootPosix = ConvertTo-MsysPath -WindowsPath $root
$gpg = Join-Path $gitUsr "bin\gpg.exe"
$gpgDirectory = Join-Path $root "gnupg"
$null = New-Item -ItemType Directory -Path $gpgDirectory -Force
$gpgDirectoryPosix = ConvertTo-MsysPath -WindowsPath $gpgDirectory
$ffmpegKeyPosix = ConvertTo-MsysPath -WindowsPath (
    Join-Path $downloads "ffmpeg-devel.asc"
)
$ffmpegSignaturePosix = ConvertTo-MsysPath -WindowsPath (
    Join-Path $downloads "ffmpeg-6.1.6.tar.xz.asc"
)
$ffmpegSourcePosix = ConvertTo-MsysPath -WindowsPath (
    Join-Path $downloads "ffmpeg-6.1.6.tar.xz"
)

$gpgImportOutput = @(
    & $gpg --batch --homedir $gpgDirectoryPosix --import $ffmpegKeyPosix 2>&1
)
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo importar la clave oficial de publicación de FFmpeg: $($gpgImportOutput -join ' ')"
}
$gpgVerifyOutput = @(
    & $gpg --batch --homedir $gpgDirectoryPosix --status-fd 1 --verify `
        $ffmpegSignaturePosix $ffmpegSourcePosix 2>&1
)
if (
    $LASTEXITCODE -ne 0 -or
    ($gpgVerifyOutput -join "`n") -notmatch (
        "\[GNUPG:\] VALIDSIG " +
        "FCF986EA15E6E293A5644F10B4322F04D67658D8\b"
    )
) {
    throw "La firma del código fuente de FFmpeg no es válida: $($gpgVerifyOutput -join ' ')"
}

$extractScript = Join-Path $metadata "extract-sources.sh"
$extractScriptContent = @'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: extract-sources.sh ROOT_POSIX" >&2
  exit 2
fi

ROOT_POSIX="$1"
mkdir -p "$ROOT_POSIX/src"

tar -xf "$ROOT_POSIX/downloads/ffmpeg-6.1.6.tar.xz" -C "$ROOT_POSIX/src"
tar -xf "$ROOT_POSIX/downloads/libogg-1.3.6.tar.xz" -C "$ROOT_POSIX/src"
tar -xf "$ROOT_POSIX/downloads/libvorbis-1.3.7.tar.xz" -C "$ROOT_POSIX/src"
tar -xf "$ROOT_POSIX/downloads/libtheora-1.2.0.tar.gz" -C "$ROOT_POSIX/src"
'@
[System.IO.File]::WriteAllText(
    $extractScript,
    $extractScriptContent.Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false)
)

$buildScript = Join-Path $metadata "build-all.sh"
$buildScriptContent = @'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: build-all.sh ROOT_POSIX JOBS" >&2
  exit 2
fi

ROOT_POSIX="$1"
JOBS="$2"
ROOT_WIN="$(cygpath -m "$ROOT_POSIX")"
TOOL_POSIX="$ROOT_POSIX/toolchain/w64devkit/bin"
TOOL_WIN="$ROOT_WIN/toolchain/w64devkit/bin"
SHELL_WIN="$ROOT_WIN/toolchain/git-usr/bin/sh.exe"
PREFIX="$ROOT_WIN/prefix"

# These variables apply only to this child shell and its compiler processes.
export PATH="/usr/bin:$TOOL_POSIX"
export TMP="$ROOT_WIN/tmp"
export TEMP="$ROOT_WIN/tmp"
export TMPDIR="$ROOT_WIN/tmp"
export SOURCE_DATE_EPOCH=1781983993
export CONFIG_SHELL="$SHELL_WIN"
export SHELL="$SHELL_WIN"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

COMMON_CFLAGS="-O2 -fno-ident -ffile-prefix-map=$ROOT_WIN=/usr/src/aurora-ffmpeg -fdebug-prefix-map=$ROOT_WIN=/usr/src/aurora-ffmpeg"
COMMON_LDFLAGS="-Wl,--no-insert-timestamp"

export CC="$TOOL_WIN/gcc.exe"
export CXX="$TOOL_WIN/g++.exe"
export AR="$TOOL_WIN/ar.exe"
export RANLIB="$TOOL_WIN/ranlib.exe"
export STRIP="$TOOL_WIN/strip.exe"
export LD="$TOOL_WIN/ld.exe"
export NM="$TOOL_WIN/nm.exe"
export DLLTOOL="$TOOL_WIN/dlltool.exe"
export OBJDUMP="$TOOL_WIN/objdump.exe"

mkdir -p \
  "$ROOT_POSIX/tmp" \
  "$ROOT_POSIX/build" \
  "$ROOT_POSIX/prefix" \
  "$ROOT_POSIX/package" \
  "$ROOT_POSIX/logs" \
  "$ROOT_POSIX/test-output"

build_ogg() {
  local build="$ROOT_POSIX/build/libogg"
  local log="$ROOT_POSIX/logs/libogg-build.log"
  mkdir -p "$build"
  cd "$build"
  CFLAGS="$COMMON_CFLAGS" \
  LDFLAGS="$COMMON_LDFLAGS" \
    ../../src/libogg-1.3.6/configure \
      --build=x86_64-w64-mingw32 \
      --host=x86_64-w64-mingw32 \
      --prefix="$PREFIX" \
      --disable-shared \
      --enable-static >"$log" 2>&1
  "$TOOL_WIN/make.exe" -j"$JOBS" >>"$log" 2>&1
  "$TOOL_WIN/make.exe" install >>"$log" 2>&1
}

build_vorbis() {
  local build="$ROOT_POSIX/build/libvorbis"
  local log="$ROOT_POSIX/logs/libvorbis-build.log"
  mkdir -p "$build"
  cd "$build"
  CFLAGS="$COMMON_CFLAGS -I$PREFIX/include" \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib $COMMON_LDFLAGS" \
    ../../src/libvorbis-1.3.7/configure \
      --build=x86_64-w64-mingw32 \
      --host=x86_64-w64-mingw32 \
      --prefix="$PREFIX" \
      --disable-shared \
      --enable-static \
      --disable-oggtest >"$log" 2>&1
  "$TOOL_WIN/make.exe" -j"$JOBS" >>"$log" 2>&1
  "$TOOL_WIN/make.exe" install >>"$log" 2>&1
}

build_theora() {
  local build="$ROOT_POSIX/build/libtheora"
  local log="$ROOT_POSIX/logs/libtheora-build.log"
  mkdir -p "$build"
  cd "$build"
  CFLAGS="$COMMON_CFLAGS -I$PREFIX/include" \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib $COMMON_LDFLAGS" \
    ../../src/libtheora-1.2.0/configure \
      --build=x86_64-w64-mingw32 \
      --host=x86_64-w64-mingw32 \
      --prefix="$PREFIX" \
      --disable-shared \
      --enable-static \
      --disable-doc \
      --disable-examples \
      --disable-oggtest \
      --disable-vorbistest >"$log" 2>&1
  "$TOOL_WIN/make.exe" -j"$JOBS" >>"$log" 2>&1
  "$TOOL_WIN/make.exe" install >>"$log" 2>&1
}

build_ffmpeg() {
  local build="$ROOT_POSIX/build/ffmpeg"
  local log="$ROOT_POSIX/logs/ffmpeg-build.log"
  mkdir -p "$build"
  cd "$build"
  CFLAGS="$COMMON_CFLAGS -I$PREFIX/include" \
  CPPFLAGS="-I$PREFIX/include" \
  LDFLAGS="-L$PREFIX/lib -static $COMMON_LDFLAGS" \
  ../../src/ffmpeg-6.1.6/configure \
    --prefix=/aurora-ffmpeg \
    --arch=x86_64 \
    --target-os=mingw32 \
    --cc=gcc \
    --cxx=g++ \
    --ar=ar \
    --ranlib=ranlib \
    --strip=strip \
    --nm=nm \
    --pkg-config=pkg-config \
    --pkg-config-flags=--static \
    --enable-static \
    --disable-shared \
    --disable-autodetect \
    --disable-everything \
    --disable-network \
    --disable-debug \
    --disable-doc \
    --disable-ffplay \
    --disable-x86asm \
    --enable-ffmpeg \
    --enable-ffprobe \
    --enable-avcodec \
    --enable-avformat \
    --enable-avfilter \
    --enable-avdevice \
    --enable-swscale \
    --enable-swresample \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-protocol=file,pipe \
    --enable-indev=lavfi \
    --enable-demuxer=aac,ac3,avi,eac3,flac,h264,hevc,m4v,matroska,mjpeg,mov,mp3,mpegvideo,ogg,wav \
    --enable-muxer=ogg,null \
    --enable-decoder=aac,aac_fixed,aac_latm,ac3,alac,av1,dca,dvvideo,eac3,ffv1,flac,h264,hevc,huffyuv,mjpeg,mp1,mp2,mp3,mpeg1video,mpeg2video,mpeg4,msmpeg4v1,msmpeg4v2,msmpeg4v3,opus,pcm_alaw,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_mulaw,pcm_s16be,pcm_s16le,pcm_s24be,pcm_s24le,pcm_s32be,pcm_s32le,pcm_u8,prores,rawvideo,theora,truehd,vc1,vorbis,vp8,vp9,wmalossless,wmapro,wmav1,wmav2,wmv1,wmv2,wmv3,wrapped_avframe \
    --enable-encoder=libtheora,libvorbis,pcm_s16le,wrapped_avframe \
    --enable-parser=aac,aac_latm,ac3,av1,dca,flac,h264,hevc,mjpeg,mpegaudio,mpeg4video,mpegvideo,opus,vc1,vorbis,vp3,vp8,vp9 \
    --enable-filter=anull,aresample,format,fps,null,scale,sine,testsrc2 \
    >"$log" 2>&1

  # FFmpeg configure sees /c/... through Git Bash. The make from w64devkit is
  # a native Windows executable and requires the same source path as C:/....
  sed -i \
    "s|^include $ROOT_POSIX/src/ffmpeg-6.1.6/Makefile$|include $ROOT_WIN/src/ffmpeg-6.1.6/Makefile|" \
    Makefile
  sed -i \
    -e "s|^SRC_PATH=$ROOT_POSIX/src/ffmpeg-6.1.6$|SRC_PATH=$ROOT_WIN/src/ffmpeg-6.1.6|" \
    -e "s|^SRC_LINK=$ROOT_POSIX/src/ffmpeg-6.1.6$|SRC_LINK=$ROOT_WIN/src/ffmpeg-6.1.6|" \
    ffbuild/config.mak

  "$TOOL_WIN/make.exe" -j"$JOBS" V=1 >>"$log" 2>&1
  mkdir -p "$ROOT_POSIX/package/bin"
  cp -f ffmpeg.exe ffprobe.exe "$ROOT_POSIX/package/bin/"
  "$TOOL_WIN/strip.exe" --strip-all "$ROOT_WIN/package/bin/ffmpeg.exe"
  "$TOOL_WIN/strip.exe" --strip-all "$ROOT_WIN/package/bin/ffprobe.exe"
}

require_capability() {
  local listing="$1"
  local name="$2"
  if ! grep -Eq "(^|[[:space:],])${name}([[:space:],]|$)" "$listing"; then
    echo "Missing required FFmpeg capability: $name" >&2
    exit 1
  fi
}

validate_runtime() {
  local ffmpeg="$ROOT_WIN/package/bin/ffmpeg.exe"
  local ffprobe="$ROOT_WIN/package/bin/ffprobe.exe"
  local output="$ROOT_WIN/test-output/synthetic.ogv"
  local version_file="$ROOT_POSIX/test-output/version.txt"
  local license_file="$ROOT_POSIX/test-output/license.txt"
  local encoders_file="$ROOT_POSIX/test-output/encoders.txt"
  local decoders_file="$ROOT_POSIX/test-output/decoders.txt"
  local filters_file="$ROOT_POSIX/test-output/filters.txt"
  local demuxers_file="$ROOT_POSIX/test-output/demuxers.txt"
  local muxers_file="$ROOT_POSIX/test-output/muxers.txt"

  "$ffmpeg" -version >"$version_file" 2>&1
  "$ffprobe" -version >>"$version_file" 2>&1
  "$ffmpeg" -L >"$license_file" 2>&1

  grep -Eq "^ffmpeg version 6\.1\.6([[:space:]]|$)" "$version_file"
  grep -Eq "^ffprobe version 6\.1\.6([[:space:]]|$)" "$version_file"
  if \
    grep -Fq -- "--enable-gpl" "$version_file" || \
    grep -Fq -- "--enable-nonfree" "$version_file" || \
    grep -Fq -- "--enable-version3" "$version_file"; then
    echo "The generated build unexpectedly enables GPL, nonfree or version3 mode." >&2
    exit 1
  fi
  for required_flag in --enable-static --disable-shared --disable-autodetect --disable-everything; do
    grep -Fq -- "$required_flag" "$version_file"
  done
  if grep -Fq "$ROOT_WIN" "$version_file"; then
    echo "The reported FFmpeg configuration exposes the local build path." >&2
    exit 1
  fi
  if \
    "$TOOL_WIN/strings.exe" -a "$ffmpeg" | grep -Fq "$ROOT_WIN" || \
    "$TOOL_WIN/strings.exe" -a "$ffprobe" | grep -Fq "$ROOT_WIN"; then
    echo "A generated executable contains the local build path." >&2
    exit 1
  fi
  grep -Fq "GNU Lesser General Public" "$license_file"
  grep -Fq "version 2.1" "$license_file"

  "$ffmpeg" -hide_banner -encoders >"$encoders_file" 2>&1
  "$ffmpeg" -hide_banner -decoders >"$decoders_file" 2>&1
  "$ffmpeg" -hide_banner -filters >"$filters_file" 2>&1
  "$ffmpeg" -hide_banner -demuxers >"$demuxers_file" 2>&1
  "$ffmpeg" -hide_banner -muxers >"$muxers_file" 2>&1

  for capability in libtheora libvorbis pcm_s16le wrapped_avframe; do
    require_capability "$encoders_file" "$capability"
  done
  for capability in h264 hevc av1 aac mp3 opus vorbis vp8 vp9 wrapped_avframe; do
    require_capability "$decoders_file" "$capability"
  done
  for capability in fps scale format; do
    require_capability "$filters_file" "$capability"
  done
  for capability in mov avi matroska m4v; do
    require_capability "$demuxers_file" "$capability"
  done
  require_capability "$muxers_file" "ogg"

  "$ffmpeg" -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=640x360:rate=30:duration=1" \
    -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=1" \
    -map 0:v:0 -map "1:a:0?" \
    -vf "fps=30,scale=w='min(1280,iw)':h=-2:flags=lanczos,format=yuv420p" \
    -c:v libtheora -g 30 -q:v 5 \
    -c:a libvorbis -q:a 4 -ac 2 \
    "$output"

  "$ffprobe" -v error \
    -show_entries stream=codec_name,width,height,sample_rate,channels \
    -show_entries format=format_name,duration \
    -of default=noprint_wrappers=1 \
    "$output" >"$ROOT_POSIX/test-output/synthetic-probe.txt"
  grep -Fq "codec_name=theora" "$ROOT_POSIX/test-output/synthetic-probe.txt"
  grep -Fq "codec_name=vorbis" "$ROOT_POSIX/test-output/synthetic-probe.txt"

  # This is the same complete decode path used by Aurora to validate OGV output.
  "$ffmpeg" -hide_banner -loglevel error -xerror -i "$output" -f null -
}

build_ogg
build_vorbis
build_theora
build_ffmpeg
validate_runtime
'@
[System.IO.File]::WriteAllText(
    $buildScript,
    $buildScriptContent.Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false)
)

$previousMsysArgumentExclusion = $env:MSYS2_ARG_CONV_EXCL
try {
    # Arguments are already expressed as MSYS paths; prevent a second rewrite.
    $env:MSYS2_ARG_CONV_EXCL = "*"

    $extractScriptPosix = "$rootPosix/metadata/extract-sources.sh"
    & $bash --noprofile --norc $extractScriptPosix $rootPosix
    if ($LASTEXITCODE -ne 0) {
        throw "Falló la extracción de los fuentes (código $LASTEXITCODE)."
    }

    $buildScriptPosix = "$rootPosix/metadata/build-all.sh"
    & $bash --noprofile --norc $buildScriptPosix $rootPosix ([string]$Jobs)
    if ($LASTEXITCODE -ne 0) {
        throw "Falló la compilación o validación. Revisa '$root\logs' (código $LASTEXITCODE)."
    }
}
finally {
    $env:MSYS2_ARG_CONV_EXCL = $previousMsysArgumentExclusion
}

$ffmpegResult = Join-Path $root "package\bin\ffmpeg.exe"
$ffprobeResult = Join-Path $root "package\bin\ffprobe.exe"
foreach ($binary in @($ffmpegResult, $ffprobeResult)) {
    if (-not (Test-Path -LiteralPath $binary)) {
        throw "La compilación terminó sin producir '$binary'."
    }
}

Write-Host ""
Write-Host "FFmpeg mínimo reproducido y validado."
Write-Host "FFmpeg : $ffmpegResult"
Write-Host "ffprobe: $ffprobeResult"
Write-Host "SHA-256 ffmpeg : $((Get-FileHash -LiteralPath $ffmpegResult -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host "SHA-256 ffprobe: $((Get-FileHash -LiteralPath $ffprobeResult -Algorithm SHA256).Hash.ToLowerInvariant())"
