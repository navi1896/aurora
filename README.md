# Aurora

Juego de ritmo local con biblioteca, editor de niveles y paquetes portátiles `.aurora`.

La biblioteca funciona completamente sin conexión. La ventana de archivos tiene pestañas **Importar** y **Exportar**: acepta uno o varios paquetes `.aurora` en una sola selección y permite exportar una canción o toda la biblioteca a una carpeta con un archivo por canción. Aurora valida el manifiesto, las rutas y los archivos antes de instalar cada paquete, y no necesita cuentas ni un servidor de canciones.

La edición de Windows consulta la última GitHub Release al abrirse. Si hay una versión nueva con un ZIP y digest SHA-256 publicados por GitHub, Aurora descarga y verifica el paquete, instala la actualización y vuelve a abrirse. Si falla la comprobación o la descarga, la instalación actual sigue disponible.

Las versiones públicas se distribuyen sin canciones ni videos protegidos. Cada jugador es responsable del contenido local que crea o comparte.
