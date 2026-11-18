# Sonidos usados en la exportacion local de Aurora

Fuente: `DJMAX-Sonidos-interfaz-gameplay.zip`, proporcionado por el usuario el
29 de septiembre de 2026. Son grabaciones de DJMAX RESPECT V, no los archivos
internos del juego. Los originales se conservan fuera del proyecto.

Los nueve recortes se transformaron en doce WAV PCM16, estereo, 48 kHz.
Tratamiento: recorte por evento, eliminacion de desplazamiento DC, atenuacion
suave de fondo bajo -48 dBFS, ajuste de picos, entrada de 2 ms y salida de
18 ms. Se preservaron tono, velocidad y canales. No habia muestras saturadas.

| Recurso | Evento |
| --- | --- |
| menu_select | Foco o seleccion en menus y configuraciones |
| song_select | Cambio de cancion en la biblioteca |
| confirm | Confirmar opciones y botones |
| resume | Continuar desde pausa |
| countdown_3, countdown_2, countdown_1, countdown_go | Ultimos tres segundos de preparacion y comienzo de la pista |
| perfect_combo | Aviso compacto al terminar sin fallos |
| stage_clear | Entrada a resultados |
| score_count | Animacion de la puntuacion |
| score_finish | Valor final de la puntuacion |

Todos se reproducen a traves del bus SFX y respetan el volumen de efectos y
el volumen maestro. Los sonidos del resultado pertenecen a esa pantalla y
se detienen al salir; las pulsaciones de interfaz tienen proteccion contra
duplicados. Los recortes de confirmacion y GO terminan cerca del evento en
la grabacion original; sus salidas se suavizaron, sin inventar audio faltante.

El paquete no contiene sonidos de aciertos ni de errores aislados; se
conservan los efectos existentes para las notas.
