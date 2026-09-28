# Publicación en línea de Aurora

El juego usa únicamente servicios públicos y sin credenciales incrustadas:

- Catálogo: `https://raw.githubusercontent.com/navi1896/aurora/main/community/catalog.json`
- Versiones del juego: API pública de la última GitHub Release de `navi1896/aurora`
- Preparación de canciones: formulario interno de **COMUNIDAD > PUBLICAR**, con paquete y ficha en `user://aurora_submissions/outbox`.
- El formulario de GitHub en `.github/ISSUE_TEMPLATE/song-submission.yml` queda únicamente como respaldo de mantenimiento mientras se conecta el servicio autenticado de recepción.

## Activar el catálogo

Al subir estos cambios a la rama `main`, Aurora leerá el catálogo remoto. Mientras el archivo todavía no esté publicado, el juego usa la copia vacía incluida en la instalación y continúa funcionando sin conexión.

Los paquetes se alojan como assets de una GitHub Release del mismo repositorio. El catálogo debe registrar URL, tamaño exacto y SHA-256. Aurora vuelve a verificar esos datos y además valida internamente el manifiesto y todos los archivos del `.aurora` antes de instalarlo.

## Publicar una actualización del juego

1. Actualiza la versión tanto en `project.godot` como en `VERSION.md`.
2. Actualiza `export_presets.cfg` con el mismo número.
3. Exporta el preset **Windows Desktop**.
4. Ejecuta:

   ```powershell
   .\tools\prepare_windows_release.ps1 -Version 1.1.0
   ```

5. Crea una GitHub Release pública, no borrador ni preliminar, con tag `v1.1.0`.
6. Adjunta `Aurora-v1.1.0-Windows.zip`.

GitHub publica el tamaño, URL y digest SHA-256 del asset en su API. Aurora solo habilita **INSTALAR** cuando esos datos están presentes y la descarga coincide exactamente. Después de cerrar el juego, un script local extrae la versión verificada sobre la instalación y vuelve a abrir `Aurora.exe`.

Si una Release no tiene un ZIP de Windows con digest, el menú solo ofrece abrir su página: no intenta instalarla automáticamente.

## Seguridad y moderación

- El ejecutable nunca guarda un token de GitHub.
- Los usuarios no pueden escribir directamente en el catálogo.
- Todo envío pasa por revisión de licencia y validación técnica.
- Solo se descargan assets del repositorio oficial mediante HTTPS.
- El contenido local y los proyectos del editor permanecen en `user://` y no se reemplazan al actualizar el programa.
