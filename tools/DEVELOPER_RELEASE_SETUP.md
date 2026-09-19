# Perfil local de publicación

El botón `PUBLICAR ESTA VERSION` solo se muestra cuando existe
`user://aurora_developer.json` en el equipo del desarrollador. Ese archivo no
forma parte del proyecto ni de los ZIP de distribución, y no guarda tokens ni
contraseñas de GitHub.

Antes de publicar, la herramienta comprueba que la versión de `project.godot`
coincida con el botón, que no haya cambios sin confirmar, que el remoto sea el
repositorio configurado y que GitHub CLI ya tenga una sesión local válida. Si
alguna comprobación falla, no exporta, no crea etiquetas y no sube nada.

La etiqueta y la publicación se crean como `vMAYOR.MENOR.PARCHE`. La firma que
muestra Windows como editor verificado es un proceso distinto: requiere un
certificado Authenticode de confianza. El nombre de compañía del ejecutable no
elimina por sí solo la advertencia de editor desconocido.
