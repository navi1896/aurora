# Herramientas de terceros usadas por Aurora

## FFmpeg

- Uso: convertir videos elegidos por el creador desde MP4, MOV, M4V, MKV,
  WebM y AVI al formato Ogg Theora que Godot reproduce directamente.
- Distribución seleccionada: BtbN FFmpeg Windows 64-bit LGPL, snapshot
  `2026-07-29`, asset `ffmpeg-n8.1-latest-win64-lgpl-8.1.zip`.
- Versión informada por los ejecutables:
  `n8.1.2-31-g8c9502e9b0-20260729`.
- Perfil legal informado por los ejecutables: GNU LGPL versión 3 o posterior.
  La configuración contiene `--enable-version3`, no contiene `--enable-gpl`
  ni `--enable-nonfree`, y desactiva libx264, libx265 y libfdk-aac.
- Integración: Aurora ejecuta `ffmpeg.exe` y `ffprobe.exe` como procesos
  separados. No se enlazan con `Aurora.exe`, no se renombran y el usuario
  puede reemplazarlos por una distribución compatible.
- SHA-256 del ZIP:
  `fce9c9c569425ec509bc90b361119ece81ee11fb7b557552c52187b497dba982`.
- SHA-256 de `ffmpeg.exe`:
  `3f6613d4f28335e76b7c2bd6c27d2c28656e32c551f7236ff484ac7cf2ebd1c0`.
- SHA-256 de `ffprobe.exe`:
  `e7bc681341cc545674e0644d864f52dad2a828ab99d4534f572cb95876b87740`.
- Scripts de compilación BtbN fijados:
  `8c736b2d6fe5da2a10a8896d01e53bfb0ca4f665`.
- Código FFmpeg fijado:
  `8c9502e9b048e21e1cae96477e338ac0635645ba`.

La receta `tools/prepare_ffmpeg_btbn.ps1` descarga el asset por una URL
fijada, verifica el hash del ZIP, extrae en una carpeta controlada y vuelve a
verificar los hashes de ambos ejecutables y de la licencia. También comprueba
la versión, el informe LGPL, las opciones de configuración y las capacidades
que Aurora necesita. `tools/package_windows.ps1` repite las comprobaciones
antes de copiar solo `ffmpeg.exe`, `ffprobe.exe` y los avisos de distribución.

Flujo de release:

```powershell
pwsh ./tools/prepare_ffmpeg_btbn.ps1
pwsh ./tools/package_windows.ps1
```

Para reutilizar una raíz auditada, pasa el mismo `-RootPath` a la preparación
y `-FfmpegBuildRoot` al empaquetador. Añade `-CreateZip` únicamente después de
que el resto de la validación de release haya terminado.

La matriz de compatibilidad está en `tools/ffmpeg_matrix_fixtures/` y se
ejecuta con `tools/test_ffmpeg_matrix.ps1`. Comprueba MP4 H.264/AAC, MOV
ProRes/PCM, M4V MPEG-4/AAC, MKV H.264/Opus, WebM VP9/Opus, AVI MJPEG/PCM,
video sin audio, Unicode, rutas con espacios y rechazo de un archivo corrupto.
Además del test sintético, este snapshot superó antes de ser seleccionado una
comparación visual automatizada con video real; esa evidencia de auditoría no
forma parte del paquete público.

El paquete conserva la configuración exacta informada por el ejecutable, los
hashes, la lista de capacidades, la licencia LGPLv3 completa, los enlaces al
código fuente correspondiente y las dependencias reportadas. La configuración
de BtbN habilita varias bibliotecas externas; su inventario se conserva sin
presentarlo como una determinación legal exhaustiva. Este documento es un
registro técnico, no asesoría legal.

La receta anterior `tools/build_ffmpeg_minimal.ps1` se conserva únicamente
como historial de investigación. Sus binarios no superaron el control visual
con video real y no son una fuente oficial para releases de Aurora.

Referencias primarias:

- https://ffmpeg.org/download.html
- https://github.com/BtbN/FFmpeg-Builds
- https://github.com/BtbN/FFmpeg-Builds/tree/8c736b2d6fe5da2a10a8896d01e53bfb0ca4f665
- https://github.com/FFmpeg/FFmpeg/commit/8c9502e9b048e21e1cae96477e338ac0635645ba
- https://github.com/FFmpeg/FFmpeg/blob/8c9502e9b048e21e1cae96477e338ac0635645ba/LICENSE.md
