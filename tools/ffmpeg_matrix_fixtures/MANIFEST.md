# Fixtures de la matriz FFmpeg de Aurora

Estos siete clips sintéticos sirven exclusivamente para pruebas de desarrollo.
No contienen música, video ni arte de terceros. El preset de exportación de
Aurora excluye `tools/*`, por lo que no se incorporan al juego distribuido.

## Generador validado

- Compilación: BtbN FFmpeg LGPL Shared 6.1
- Versión: `ffmpeg version n6.1.3-20250831`
- Archivo binario original:
  `ffmpeg-n6.1.3-win64-lgpl-shared-6.1.zip`
- SHA-256 del archivo binario:
  `b5af042081d2f7887c18894801e1d91ccb6d565ebcea0d32c0070869f5f611cc`
- Ruta de desarrollo autorizada:
  `%LOCALAPPDATA%\AuroraDevTools\ffmpeg-6.1.3-lgpl-shared\ffmpeg-n6.1.3-win64-lgpl-shared-6.1\bin\ffmpeg.exe`

La reproducción byte a byte requiere esa compilación exacta. Los clips duran un
segundo, miden 320×180 y usan una señal visual `testsrc2` y un tono sintético de
440 Hz. La variante Unicode no contiene audio.

## Comandos de reproducción

Ejecutar desde esta carpeta en PowerShell:

```powershell
$ff = Join-Path $env:LOCALAPPDATA "AuroraDevTools\ffmpeg-6.1.3-lgpl-shared\ffmpeg-n6.1.3-win64-lgpl-shared-6.1\bin\ffmpeg.exe"
$video = @("-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=24:duration=1")
$audio = @("-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=1", "-shortest")
$common = @("-map_metadata", "-1", "-threads", "1")

& $ff @video @audio @common -c:v libopenh264 -b:v 600k -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart -f mp4 "01-mp4-h264-aac.mp4"
& $ff @video @audio @common -c:v prores_ks -profile:v 0 -pix_fmt yuv422p10le -c:a pcm_s16le -f mov "02-mov-prores-pcm.mov"
& $ff @video @audio @common -c:v mpeg4 -q:v 4 -pix_fmt yuv420p -c:a aac -b:a 128k -f mp4 "03-m4v-mpeg4-aac.m4v"
& $ff @video @audio @common -c:v libopenh264 -b:v 600k -pix_fmt yuv420p -c:a libopus -b:a 96k -f matroska "04-mkv-h264-opus.mkv"
& $ff @video @audio @common -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -b:v 500k -pix_fmt yuv420p -c:a libopus -b:a 96k -f webm "05-webm-vp9-opus.webm"
& $ff @video @audio @common -c:v mjpeg -q:v 5 -pix_fmt yuvj420p -c:a pcm_s16le -f avi "06-avi-mjpeg-pcm.avi"
& $ff @video @common -c:v mpeg4 -q:v 4 -pix_fmt yuv420p -an -f mp4 "07-sin-audio-español-日本語.mp4"
```

## Inventario y hashes

| Archivo | Video | Audio | Bytes | SHA-256 |
|---|---|---|---:|---|
| `01-mp4-h264-aac.mp4` | H.264 | AAC | 93,252 | `A2F6049EA93BDC6A0C9633D72A8F9DF6A43569EEA45D76825692DAAF10B4067E` |
| `02-mov-prores-pcm.mov` | ProRes | PCM S16LE | 290,565 | `700C4ADF8EDC3F178D0CC6F7B0DEED478337AF3B34C0953F90693E0F79CE447A` |
| `03-m4v-mpeg4-aac.m4v` | MPEG-4 Part 2 | AAC | 111,567 | `04614205BD2B947FDEA621542DD5784ADF44E56326D865542E8C90CC8FD45A25` |
| `04-mkv-h264-opus.mkv` | H.264 | Opus | 92,745 | `D347142AA44332E149AD98D22B7236962ACA14A7A9C6E2320E9993D986188CBA` |
| `05-webm-vp9-opus.webm` | VP9 | Opus | 62,044 | `B45D7B3108D168890CA81E5435F57FA68712FBA2311B86006498B456ACDC420C` |
| `06-avi-mjpeg-pcm.avi` | Motion JPEG | PCM S16LE | 291,384 | `091BB6836248E6C015F8B55DDEC6C0730A1D325380A0ECE0B142F8F5ACF727E6` |
| `07-sin-audio-español-日本語.mp4` | MPEG-4 Part 2 | Sin audio | 94,934 | `0E77C60F436815E774F64CEBBE283906C855848DEDD424F49AC04CF2C4D57CA3` |

Tamaño total de los siete clips: 1,036,491 bytes.

`test_ffmpeg_matrix.ps1` comprueba estos hashes antes de cada ejecución. El
archivo corrupto se crea dentro de un directorio temporal verificado y se
elimina al finalizar; no forma parte de este inventario.
