# Biblioteca Compartida y Sincronización en la Nube (Aurora)

Esta carpeta permite sincronizar canciones, niveles, pantallas de carga y videos entre tu PC principal, tu laptop y cualquier otro equipo usando **Google Drive**, **OneDrive**, **Dropbox** o una carpeta compartida en red local, sin necesidad de inicio de sesión ni servidor backend.

## Cómo usarla

1. **Carpeta sincronizada automática (`cloud_sync_directory`)**
   - Coloca tus canciones exportadas (`.aurora` o carpetas de paquete descomprimidas) dentro de una carpeta sincronizada en Google Drive / OneDrive (por ejemplo, `G:\Mi unidad\AuroraLibrary`).
   - En `user://settings.json` (o desde la configuración), asigna `"cloud_sync_directory"` a esa ruta en cada PC o dispositivo.

2. **Carpeta portátil (`shared_library/`)**
   - También puedes colocar paquetes o sincronizar directamente una carpeta llamada `shared_library` junto a `Aurora.exe` (o aquí mismo si ejecutas desde el proyecto).
   - Aurora detectará automáticamente tanto carpetas de paquete ya extraídas como archivos `.aurora` nuevos o actualizados dentro de `shared_library/` o `shared_library/packages/`.

## Privacidad y Git

Todo el contenido multimedia colocado dentro de esta carpeta es ignorado por `shared_library/.gitignore` para que las canciones y videos nunca se suban a GitHub.
