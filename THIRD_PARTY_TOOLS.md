# Herramientas de terceros usadas por Aurora

## FFmpeg

- Uso: convertir videos elegidos por el creador desde MP4, MOV, M4V, MKV,
  WebM y AVI al formato Ogg Theora que Godot reproduce directamente.
- Versión distribuida: FFmpeg 6.1.6 para Windows x86_64.
- Perfil: compilación mínima, estática y separada de `Aurora.exe`, bajo
  GNU LGPL 2.1 o posterior.
- Bibliotecas externas incluidas: libogg 1.3.6, libvorbis 1.3.7 y
  libtheora 1.2.0.
- Componentes GPL o `nonfree`: ninguno; la configuración no usa
  `--enable-gpl`, `--enable-nonfree` ni `--enable-version3`.
- Ruta local de la compilación validada:
  `%LOCALAPPDATA%\AuroraDevTools\ffmpeg-minimal-build\package\bin\`.
- Receta de reconstrucción:
  `tools/build_ffmpeg_minimal.ps1`.
- Receta exacta usada por el binario distribuido, conservada durante el
  empaquetado:
  `licenses/FFmpeg/source/build_ffmpeg_minimal.ps1` y
  `licenses/FFmpeg/source/build-all.sh`.
- SHA-256 de `ffmpeg.exe`:
  `a395c847b0f070012c0c0f7076f098ad11dd85754a8eecc9c59b0c10004bdd99`.
- SHA-256 de `ffprobe.exe`:
  `fe7f73bbe528291779020e4272de2a5ef6bfb85a7ce475358c14cea2ca0c50eb`.

Aurora limita la conversión a un ancho máximo de 1280, 30 FPS, Theora
calidad 5 y Vorbis calidad 4. Antes de conservar la caché, decodifica la
salida completa y rechaza archivos incompletos o dañados. La clave de caché
combina ruta normalizada, tamaño, fecha de modificación y muestras SHA-256
del principio, centro y final del archivo para detectar reemplazos sin
bloquear la interfaz leyendo videos completos.

La matriz de compatibilidad permanente está en
`tools/ffmpeg_matrix_fixtures/` y se ejecuta con
`tools/test_ffmpeg_matrix.ps1`. Comprueba MP4 H.264/AAC, MOV ProRes/PCM,
M4V MPEG-4/AAC, MKV H.264/Opus, WebM VP9/Opus, AVI MJPEG/PCM, video sin
audio, Unicode, rutas con espacios y rechazo de un archivo corrupto.

El paquete público conserva `ffmpeg.exe` y `ffprobe.exe` en
`tools/ffmpeg/bin/`. También incluye, dentro de `licenses/FFmpeg/`, la
licencia, los avisos, la configuración exacta, la receta y los archivos
fuente correspondientes. No se distribuyen DLL de FFmpeg ni se necesita
una instalación externa.

Referencias primarias:

- https://ffmpeg.org/
- https://ffmpeg.org/legal.html
- https://ffmpeg.org/releases/
- https://xiph.org/downloads/
- https://github.com/skeeto/w64devkit
