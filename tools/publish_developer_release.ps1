param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$GodotExecutable,
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param([bool]$Ok, [string]$Message, [hashtable]$Extra = @{})
    $payload = @{ ok = $Ok; message = $Message; version = $Version; completed_utc = [DateTime]::UtcNow.ToString('o') }
    foreach ($entry in $Extra.GetEnumerator()) { $payload[$entry.Key] = $entry.Value }
    $directory = Split-Path -Parent $ResultPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $ResultPath -Encoding utf8
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'project.godot'))) { throw 'No se encontró el proyecto Aurora configurado.' }
    $git = Get-Command git.exe -ErrorAction Stop
    $gh = Get-Command gh.exe -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) { throw 'No se encontró el ejecutable local de Godot para exportar.' }
    $projectVersion = Select-String -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Pattern '^config/version="([^"]+)"' | Select-Object -First 1
    if ($null -eq $projectVersion -or $projectVersion.Matches[0].Groups[1].Value -ne $Version) { throw "La versión del proyecto no coincide con v$Version." }
    $dirty = & $git.Source -C $ProjectRoot status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo comprobar el estado del repositorio.' }
    if (-not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))) { throw 'Hay cambios sin confirmar. Revisa y confirma una versión antes de publicar.' }
    $remote = & $git.Source -C $ProjectRoot remote get-url origin
    if ($LASTEXITCODE -ne 0 -or $remote -notmatch [regex]::Escape($Repository)) { throw 'El repositorio configurado no coincide con el remoto de este proyecto.' }
    & $gh.Source auth status | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI no tiene una sesión válida en este equipo.' }
    $tag = "v$Version"
    $existingTag = & $git.Source -C $ProjectRoot tag -l $tag
    if (-not [string]::IsNullOrWhiteSpace(($existingTag -join ""))) { throw "La etiqueta $tag ya existe." }
    $releaseDir = Join-Path $ProjectRoot ("build\Aurora-v{0}-Windows" -f $Version)
    $exePath = Join-Path $releaseDir 'Aurora.exe'
    $zipPath = Join-Path $ProjectRoot ("build\Aurora-v{0}-Windows.zip" -f $Version)
    $hashPath = "$zipPath.sha256"
    if ((Test-Path -LiteralPath $releaseDir) -or (Test-Path -LiteralPath $zipPath) -or (Test-Path -LiteralPath $hashPath)) { throw 'Ya existen archivos de salida para esta versión; no se sobrescribieron.' }
    & $GodotExecutable --headless --path $ProjectRoot --export-release 'Windows Desktop' $exePath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) { throw 'La exportación de Windows no se completó.' }
    Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
    if (-not (Test-Path -LiteralPath $zipPath)) { throw 'No se pudo crear el ZIP de distribución.' }
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    Set-Content -LiteralPath $hashPath -Value "$hash  $([IO.Path]::GetFileName($zipPath))" -Encoding ascii
    & $gh.Source release create $tag $zipPath $hashPath --repo $Repository --title "Aurora $tag" --generate-notes
    if ($LASTEXITCODE -ne 0) { throw 'GitHub no pudo crear la publicación.' }
    Write-Result $true "v$Version se publicó en GitHub." @{ archive_path = $zipPath; sha256 = $hash }
}
catch {
    Write-Result $false $_.Exception.Message
    exit 1
}
