# Catálogo comunitario de Aurora

Aurora consulta `catalog.json` en la rama `main`. El catálogo empieza vacío: una canción solo se añade después de revisar su paquete y confirmar que quien la envía tiene permiso para compartir audio, video, portada y chart.

## Publicar una canción

1. En la biblioteca, selecciona una canción creada en Aurora y abre **COMUNIDAD > PUBLICAR**.
2. Aurora completa título, artista, versión, chart y medios. El autor agrega licencia, créditos y confirma que puede compartirlos.
3. **PREPARAR PUBLICACIÓN** genera automáticamente el `.aurora` y una ficha `.submission.json` verificada en `user://aurora_submissions/outbox` sin modificar el proyecto original.
4. Cuando el servicio autenticado de recepción esté conectado, esa misma pantalla enviará ambos archivos para revisión. Mientras tanto, un mantenedor puede procesar la bandeja preparada de forma manual.
5. Tras la revisión, el paquete se publica como asset de una GitHub Release y se registra en `catalog.json` su URL, tamaño exacto y SHA-256.

Nunca deben aceptarse archivos extraídos de otros juegos, películas o videos sin autorización.

## Entrada del catálogo

```json
{
	"package_id": "autor-cancion",
	"package_version": "1.0.0",
	"title": "Título",
	"artist": "Artista",
	"author": "Creador del chart",
	"description": "Descripción breve",
	"license": "CC BY 4.0",
	"key_modes": [4],
	"download_url": "https://github.com/navi1896/aurora/releases/download/songs-2026-08/autor-cancion-v1.0.0.aurora",
	"size_bytes": 123456,
	"sha256": "64-caracteres-hexadecimales"
}
```

El juego rechaza dominios ajenos al repositorio, rutas sin HTTPS, archivos que no terminen en `.aurora`, tamaños mayores de 512 MiB y descargas cuyo SHA-256 no coincida.
