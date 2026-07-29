# Progreso automático de Aurora

## 2026-07-24 — Feedback EARLY / LATE

- Añadido un indicador discreto de sincronización debajo del juicio.
- Muestra `ON TIME`, `EARLY` o `LATE` junto con la diferencia en milisegundos.
- Mantiene la información dentro del playfield para no tapar el video.
- Añadidas comprobaciones automáticas para pulsaciones tempranas y tardías.

## 2026-07-24 — Resumen de timing en resultados

- Registrado el promedio de adelanto o retraso de las pulsaciones acertadas.
- La pantalla de resultados muestra `ON TIME`, `EARLY` o `LATE` con el sesgo medio.
- Las pulsaciones dentro de ±8 ms se contabilizan como centradas.
- Añadidas pruebas del promedio y de los contadores temprano, tardío y centrado.

## 2026-07-24 — Pulso y hitos de combo

- El contador de combo responde con un pulso breve en cada acierto.
- Cada diez notas recibe un énfasis dorado y muestra el hito como `10 CHAIN`, `20 CHAIN`, etc.
- Un `MISS` restablece inmediatamente el estado visual.
- La animación se omite cuando está activo el movimiento reducido.

## 2026-07-24 — Límites claros de velocidad

- Los controles de velocidad de la biblioteca y la pausa reconocen los límites `1.0x` y `10.0x`.
- El botón correspondiente se desactiva al alcanzar el mínimo o el máximo.
- El estado se actualiza inmediatamente después de cada ajuste.
- Añadidas pruebas para ambos extremos sin modificar la configuración guardada.

## 2026-07-24 — Cuenta regresiva al continuar

- Reanudar desde pausa muestra `3`, `2`, `1` y `GO!`.
- El árbol del juego permanece pausado durante toda la cuenta.
- Las notas, el video y los controles de carril no avanzan antes de `GO!`.
- Añadidas pruebas del estado pausado, la visibilidad y la reanudación final.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Feedback de carril al fallar

- Un `MISS` produce un destello coral breve únicamente en el receptor del carril responsable.
- El efecto respeta la opción existente para desactivar efectos de impacto.
- El destello se limpia automáticamente y no ocupa espacio sobre el video.
- Añadidas comprobaciones del color inicial y su restauración.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Estado especial en resultados

- La pantalla de resultados distingue entre `PERFECT PLAY`, `FULL COMBO` y `TRACK COMPLETE`.
- El estado se calcula con el total de notas, los aciertos perfectos y los fallos reales.
- Cada estado utiliza un color de la paleta neón de Aurora.
- Añadidas comprobaciones para los tres resultados posibles.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Distribución de sincronización

- Los resultados muestran cuántos aciertos fueron `EARLY`, centrados y `LATE`.
- El resumen aparece debajo del sesgo promedio con el formato compacto `EARLY / ON / LATE`.
- La información reutiliza los contadores existentes y no añade datos redundantes durante el gameplay.
- Añadida una comprobación del formato mostrado.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Sonido discreto de fallo

- Un `MISS` reproduce un tono corto y grave para reforzar el error sin depender únicamente de la vista.
- El sonido se genera dentro de Aurora y no utiliza recursos externos ni material con licencia.
- Se reproduce por el canal `SFX`, por lo que respeta el volumen de efectos.
- Añadidas comprobaciones de creación y reproducción.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Selección por borde azul

- Los botones compartidos conservan exactamente el mismo relleno al recibir foco o cursor.
- La selección se comunica únicamente mediante un borde azul neón más brillante.
- El estado presionado permanece separado para conservar respuesta al confirmar.
- Añadidas comprobaciones del relleno y del color del borde.
- Validado sin fugas con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Timing claro después de un MISS

- Un `MISS` reemplaza el valor EARLY/LATE anterior por `NO INPUT`.
- La lectura evita atribuir al fallo el tiempo de una nota acertada previamente.
- El aviso usa el coral de error y permanece dentro del playfield.
- Añadida una comprobación de limpieza del valor anterior.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-24 — Reasignación de teclas sin duplicados

- Al elegir una tecla que ya pertenece a otro carril, Aurora intercambia ambas asignaciones.
- Ningún carril queda accidentalmente compartiendo la misma tecla.
- La operación conserva la tecla anterior en lugar de borrar una configuración útil.
- Añadida una comprobación del intercambio en modo 4K.
- Validado con la prueba integral y la revisión de todos los scripts de Godot.

## 2026-07-25 — Localización real y recorrido manual

- La preferencia `Español / English` ahora cambia realmente los textos de menú, biblioteca, configuración, gameplay, pausa, resultados y editor.
- El idioma se valida, se aplica al iniciar y permanece guardado entre ejecuciones.
- Añadidas comprobaciones automáticas para ambos idiomas sin modificar las preferencias del usuario.
- Recorrido manual completado con control de escritorio: cambio de idioma, selección de canción y 6K, entrada, pausa, velocidad, continuar, reiniciar, resultados, biblioteca, editor y salida.
- Verificado el video de fondo autorizado de prototipo en Aurora Demo y el regreso a la biblioteca desde pausa.
- Sin errores de juego ni de scripts; el único mensaje informativo fue la limitación normal de modo ventana del juego embebido de Godot.

## 2026-07-25 — Línea elevada y juicios más accesibles

- La línea de impacto y el punto real de llegada de las notas se elevaron juntos.
- Se conserva una separación fija de 30 píxeles lógicos respecto al borde superior de los receptores, equivalente a una nota y media.
- Las ventanas de juicio se ampliaron moderadamente: `PERFECT ±65 ms`, `GREAT ±115 ms`, `GOOD ±170 ms` y fallo después de `±220 ms`.
- Añadidas comprobaciones de separación, clasificación de juicios y compatibilidad con 4K, 6K y 8K.
- Validado visualmente con Aurora Demo, prueba integral y registros de Godot sin errores.

## 2026-07-25 — Editor funcional y notas sostenidas

- La línea de impacto ahora es una zona translúcida de 40 píxeles, aproximadamente tres cuartos de una tecla, sin perder la separación respecto a los receptores.
- Se eliminó por completo el sonido local al pulsar carriles y se retiró su opción de Configuración y Pausa.
- El editor permite seleccionar un OGV externo, conservar su audio integrado o añadir audio separado, y copia los archivos a datos de usuario sin alterar los originales.
- El modo manual graba taps y notas sostenidas mientras avanza el video; permite 4K, 6K y 8K, búsqueda en timeline, deshacer, limpiar, guardar, importar y probar.
- El modo automático crea una base determinista por BPM con tres densidades y algunas notas sostenidas para revisión manual posterior.
- Los proyectos guardados aparecen en la biblioteca mediante `SongManager`, siempre que tengan video y chart válidos.
- Las notas sostenidas fallan si no se inician o se sueltan antes de la mitad, conservan puntaje mínimo después de la mitad y usan PERFECT/GREAT/GOOD alrededor de la cola.
- Se añadió documentación del formato, compatibilidad con charts anteriores y pruebas automáticas de línea, silencio, generación, editor y reglas de hold.
- Validado visualmente en 1920×1080, con prueba integral `SMOKE TEST PASSED` y sin errores de ejecución.

## 2026-07-25 — Importación de MP4 y niveles solo audio

- El selector del editor acepta OGV, MP4, MOV, MKV, WebM, AVI y M4V.
- Los formatos que Godot no reproduce directamente se convierten en segundo plano a una copia Ogg Theora interna; el archivo original nunca se modifica.
- El editor muestra el estado de la conversión, bloquea temporalmente las acciones incompatibles y limpia copias incompletas si se abandona la pantalla.
- Se añadió detección de FFmpeg en la ruta del sistema y en instalaciones portátiles de WinGet.
- MP3, OGG y WAV también pueden usarse sin video: habilitan reproducción, grabación manual, generación automática, guardado y prueba del chart.
- Probado dentro de Godot con un fragmento del MP4 autorizado `Demon Slayer.mp4` y con `break.mp3`; ambos originales permanecieron intactos y las copias de prueba se limpiaron.
- Corregido el UID de `Editor.gd` en la escena para eliminar el aviso de recurso inválido.
- Validado con revisión de scripts, conversión Theora/Vorbis real, reproducción visual y `SMOKE TEST PASSED`.

## 2026-07-25 — Video estable y flujo completo de prueba del editor

- Diagnosticada la corrupción del MP4: el OGV generado por FFmpeg 8.1.2 contenía errores de
  bitstream Theora incluso fuera de Godot.
- El editor ahora usa un conversor Theora 5.x/6.x compatible, limita la copia a 720p/30 fps,
  muestra progreso y valida la decodificación antes de cargarla.
- `Demon Slayer.mp4` se convirtió completo a 86.84 segundos; el OGV resultante pasó una
  decodificación integral sin errores y se revisó visualmente en distintos puntos.
- La copia dañada anterior se invalidó y el proyecto `Nuevo nivel` quedó actualizado sin tocar
  el MP4 original ni perder sus 181 notas y 15 notas sostenidas.
- El video de gameplay ya no entra en bucle cuando termina la canción.
- Las pruebas iniciadas desde el editor recuerdan el proyecto de origen. Pausa, resultados y
  Escape ofrecen volver al editor y restauran el chart guardado para seguir trabajando.
- Manual/Automática ahora usa un interruptor legible; `Probar chart` permanece en la barra
  principal.
- La grabación manual muestra una preparación de dos segundos y Espacio controla la vista
  previa.
- Las pruebas del editor esperan Espacio y muestran `2–1–¡YA!`; las partidas normales arrancan
  directamente con video, audio y notas sincronizados.
- Ocultar el fondo conserva la reproducción interna para que una canción con audio integrado
  no se congele ni pierda sincronización.
- Validado con recorrido real Editor → Gameplay → Pausa/Resultados → Editor, restaurando
  181/181 notas, revisión de registros y prueba integral `SMOKE TEST PASSED`.

## 2026-07-25 — Vista previa y borrado recuperable en la biblioteca

- La ficha de cada canción puede reproducir una vista previa visible del video y su audio.
- Se añadió un control dedicado para iniciar o detener la preescucha; también responde a `P`.
- Los niveles creados en el editor ofrecen `BORRAR CANCION`, mientras que el contenido incluido
  con Aurora permanece protegido.
- El borrado requiere una confirmación temática dentro del juego y mueve la carpeta del nivel
  a la Papelera de Windows para que pueda recuperarse.
- `Escape` cancela la confirmación sin salir de la biblioteca y `Supr` abre el aviso de borrado.
- Validado visualmente con `Demon Slayer`, sin confirmar ningún borrado; ambos proyectos del
  editor permanecieron intactos.
- Revisión de scripts y prueba integral completadas con `SMOKE TEST PASSED`.

## 2026-07-25 — Compatibilidad nativa con mandos Xbox y PlayStation

- El teclado y cualquier mando compatible con el sistema de entradas de Godot funcionan a la vez.
- Se añadieron distribuciones simétricas para 4K, 6K y 8K; el modo 8K usa LB/RB o L1/R1
  para los carriles exteriores.
- Los receptores cambian automáticamente entre las etiquetas de teclado y mando según el
  último dispositivo utilizado.
- A/Cross inicia la canción y confirma, Menu/Options abre la pausa y B/Circle vuelve o continúa.
- La biblioteca permite seleccionar canciones y modos con el D-pad, jugar con A/Cross,
  previsualizar con Y/Triangle y abrir el borrado protegido con X/Square.
- El editor manual también permite grabar taps y notas sostenidas con la distribución del mando.
- Configuración muestra si hay un mando conectado y enseña las distribuciones específicas de
  Xbox y PlayStation para 4K, 6K y 8K.
- Revisado visualmente dentro de Godot con un `XInput Controller` detectado; las distribuciones
  4K y 8K permanecen legibles y dentro de 1920×1080.
- Validado con revisión de scripts, simulación de entradas de mando, pausa, cuenta regresiva y
  prueba integral `SMOKE TEST PASSED`.

## 2026-07-25 — Controles reasignables y música del menú

- Los carriles de mando para 4K, 6K y 8K ahora pueden reasignarse desde Configuración.
- También se pueden cambiar Confirmar, Volver, Pausa/Reproducir, Vista previa y Borrar; una
  asignación repetida intercambia los botones para evitar conflictos silenciosos.
- Menús, biblioteca, editor, gameplay, pausa y resultados consultan las asignaciones guardadas
  en lugar de depender de botones fijos.
- Las ayudas visibles muestran el botón configurado y reconocen nombres de Xbox y PlayStation.
- Las partidas normales comienzan de inmediato; la orden Espacio/Confirmar y la cuenta `2–1`
  quedan reservadas para pruebas iniciadas desde el editor.
- Se añadió una composición chiptune original y sintetizada para el menú principal y
  Configuración.
- El mezclador separa `Música del menú` de `Música de canciones`; ambas siguen respondiendo al
  volumen maestro.
- Validado con revisión de scripts, comprobaciones de buses y entradas, carga visual del menú y
  prueba integral `SMOKE TEST PASSED`.

## 2026-07-26 — Idle sutil del personaje principal

- El personaje del menú ahora respira con un cambio máximo de dos píxeles y acompaña el ciclo
  con un desplazamiento lateral de un píxel.
- Se añadió un parpadeo breve derivado en tiempo de ejecución del sprite aprobado, sin reemplazar
  ni duplicar el arte original.
- El movimiento usa posiciones enteras, anclaje inferior y filtrado nearest para mantener el
  pixel-art nítido y evitar que los pies se desplacen.
- Activar `Reducir movimiento` devuelve inmediatamente al personaje a su pose completamente
  estática y conserva los ojos abiertos.
- Revisado dentro de Godot con los ojos abiertos y durante el parpadeo: el personaje conserva
  el anclaje de los pies, no invade los botones y mantiene los píxeles definidos.
- Validado con revisión de scripts y prueba integral `SMOKE TEST PASSED`.

## 2026-07-26 — Respuesta de los audífonos al navegar

- Cambiar la opción enfocada del menú produce un destello cian breve alrededor de los
  audífonos del personaje.
- La respuesta funciona con teclado, ratón y mando porque escucha el foco compartido de los
  botones, sin alterar su navegación ni activar ninguna opción.
- El contorno usa geometría escalonada sin antialias y una duración de 0.24 segundos para
  mantener el estilo pixel-art y no distraer.
- `Reducir movimiento` desactiva inmediatamente esta respuesta interactiva.
- Revisado dentro de Godot navegando entre opciones: el destello permanece sobre los audífonos,
  no mueve al personaje ni invade los botones.
- Validado con revisión de scripts y prueba integral `SMOKE TEST PASSED`.

## 2026-07-26 — Contexto de la canción en pausa

- El menú de pausa ahora identifica la canción actual sin obligar a salir del gameplay.
- Debajo de `PAUSA` se muestran el título, artista, modo de teclas y dificultad del chart
  seleccionado, manteniendo la jerarquía visual neón del menú.
- Si no existe una canción activa, el bloque se oculta para evitar información de ejemplo.
- Revisado dentro de Godot durante una partida: el contexto permanece centrado, legible y no
  desplaza ni invade los botones o los ajustes.
- Validado con revisión de scripts, comprobaciones específicas de la información de pista y
  prueba integral `SMOKE TEST PASSED`.

## 2026-07-26 — Progreso visible durante la pausa

- La información de pista del menú de pausa ahora incluye una barra de avance discreta.
- Junto a la barra se muestran el tiempo transcurrido y la duración total de la canción en
  formato `mm:ss`.
- El valor se actualiza justo antes de abrir la pausa y permanece congelado mientras el juego
  está detenido, por lo que representa exactamente el punto de reanudación.
- Revisado dentro de Godot después de avanzar una partida: la barra y el tiempo son legibles,
  permanecen centrados y no invaden los botones ni los ajustes.
- Validado con revisión de scripts, comprobaciones de formato y proporción de avance, y prueba
  integral `SMOKE TEST PASSED`.
