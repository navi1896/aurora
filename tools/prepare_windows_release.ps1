param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $projectRoot "build\Aurora-v$Version-Windows"
$executablePath = Join-Path $buildDirectory 'Aurora.exe'
$archivePath = Join-Path $projectRoot "build\Aurora-v$Version-Windows.zip"
$hashPath = "$archivePath.sha256"

if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "No existe $executablePath. Exporta primero el preset Windows Desktop."
}
if (Test-Path -LiteralPath $archivePath) {
    throw "Ya existe $archivePath. No se sobrescribirá una versión publicada."
}

Compress-Archive -Path (Join-Path $buildDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$archiveSize = (Get-Item -LiteralPath $archivePath).Length
Set-Content -LiteralPath $hashPath -Value "$archiveHash  Aurora-v$Version-Windows.zip" -Encoding ascii

Write-Output "RELEASE_READY=$archivePath"
Write-Output "SIZE_BYTES=$archiveSize"
Write-Output "SHA256=$archiveHash"
Write-Output "Publica una GitHub Release no preliminar con tag v$Version y adjunta el ZIP."
