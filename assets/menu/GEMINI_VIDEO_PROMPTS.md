# Prompts para Video con IA (Gemini / Veo) — Menú Principal de Proyecto Aurora

Este archivo reúne los prompts listos para copiar y pegar en **Gemini / Veo** para generar los dos videos del menú principal:
1. **Animación inicial (`cabina_menu_intro`)**: se reproduce una sola vez al abrir el menú.
2. **Animación continua en reposo / idle (`cabina_menu_loop`)**: bucle continuo con la chica ya sentada frente a la cabina.

---

## Reglas importantes antes de generar

1. **Formato:** `16:9` (ideal `1080p` o `720p`, sin audio o luego se silencia al convertir).
2. **Imágenes de referencia incluidas en este proyecto:**
   - Escena completa (chica sentada + cabina + UI): `assets/menu/background/cabina_aurora_menu.png`
   - Fondo limpio sin chica (para entradas o primer frame): `assets/menu/background/cabina_aurora_menu_bg.png`
   - Personaje aislado (referencia exacta de diseño y ropa): `assets/menu/character/aurora_girl_sit_idle.png`
3. **Cámara y botones 100% bloqueados:** En Godot, la tarjeta de la canción y los clics de **JUGAR**, **CREAR**, **OPCIONES** y **SALIR** están anclados a coordenadas exactas de la imagen. Por eso todos los prompts incluyen bloquear la cámara (`locked-off static camera`) y evitar que los botones o textos cambien de posición o forma.
4. **Tema de la pierna izquierda:** Como en la ilustración original sentada la pierna izquierda queda oculta detrás del muslo/caja, en los prompts de entrada se indica explícitamente mantener **ambas piernas y ambos tenis completos** al caminar para que no se vea cortada.
5. **Cómo integrarlo al juego cuando ya tengas tus `.mp4`:**
   ```powershell
   .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_intro.mp4" -Role intro
   .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_loop.mp4" -Role loop
   ```
   El script los guarda en `assets/menu/video/` como `cabina_menu_intro.ogv` y `cabina_menu_loop.ogv`, y `CabinaMenu.gd` los detecta y reproduce automáticamente (`intro` -> `loop`, respetando el modo *Reducir movimiento*).

---

## BLOQUE 1 — Prompts para Animación Inicial (`cabina_menu_intro`)

### Opción 1A (Recomendada): Primer Frame + Último Frame (transición exacta al menú)
- **Cómo usarlo en Gemini / Veo:**
  - **First Frame (Imagen inicial):** `assets/menu/background/cabina_aurora_menu_bg.png`
  - **Last Frame (Imagen final):** `assets/menu/background/cabina_aurora_menu.png`
  - **Ventaja:** Garantiza que el video arranque con la cabina vacía encendiéndose y termine *exactamente* alineado en la pose y UI del menú y del loop.

```text
2D anime-inspired arcade game menu cinematic intro, locked-off static wide-angle tripod camera with zero camera movement, zero pan, zero zoom, zero shake. Keep the central arcade cabinet, the glowing "AURORA" logo, the center monitor screen, the magenta-cyan "JUGAR" hexagon button, and the right-side "CREAR", "OPCIONES", and "SALIR" UI panels completely fixed in their exact coordinates and crisp throughout the shot. Starting from the empty illuminated stage, neon lights on the cabinet and wet concert floor power up smoothly while the cyan-and-magenta anime girl (wearing glowing star headphones, oversized black streetwear jacket with four-point star patches, dark cargo joggers, and chunky cyan-soled platform sneakers on both complete legs and feet) walks casually in from the far left side along the wet floor, turns naturally toward the metal flight case on the bottom left, sits down smoothly on the corner of the flight case, rests her right hand on the case edge and her left elbow on her knee supporting her chin, settling cleanly into the exact final seated pose. Subtle swaying glowsticks in the distant crowd on the lower right, gentle aurora waves in the night sky, crisp anime linework, smooth natural human weight and timing, no warping, no text morphing.
```

---

### Opción 1B: Solo con imagen de referencia (si la herramienta no tiene selector First/Last Frame)
- **Cómo usarlo:** Adjunta `assets/menu/background/cabina_aurora_menu_bg.png` y `assets/menu/character/aurora_girl_sit_idle.png` (o solo `cabina_aurora_menu.png` si tu modo permite una sola imagen y quieres que primero se encienda y haga un ligero acomodo sentado).

```text
2D anime arcade rhythm-game title screen intro animation based on the attached style and character design, strictly locked static wide tripod shot, zero camera pan or zoom. Keep the central "AURORA" arcade cabinet frame, "JUGAR" button, right-side menu buttons ("CREAR", "OPCIONES", "SALIR"), and typography sharp and immovable. At the start of the clip, the cabinet neon strips and dark monitor power on with a soft cyan-magenta glow while the anime girl (long dark indigo hair fading into cyan and magenta tips, glowing headphones, oversized black jacket, dark cargo joggers, both legs clearly visible wearing matching chunky cyan-soled platform sneakers) steps smoothly into frame from the left, sits comfortably onto the metal flight case on the left foreground, crosses her arm up so her left hand gently rests under her chin while her right leg plants firmly on the reflective floor. Soft hair settle motion, distant concert crowd gently waving glowsticks, shimmering aurora borealis in the starry night sky, smooth 24fps anime motion, clean line art, zero UI distortion.
```

---

### Opción 1C: Variación rápida (cámara fija, escena ya con la chica entrando en el último paso / acomodándose sin caminar tanto)
- **Útil si 1A o 1B deforman caras al caminar desde muy lejos.** Adjunta `cabina_aurora_menu.png` como referencia de llegada o imagen principal.

```text
2D anime game title screen opening sequence, strictly locked-off static camera, no zoom, no pan, UI panels and cabinet buttons completely frozen in exact original layout. Starting slightly dimmed, neon magenta and cyan stage lights and cabinet rim lights smoothly illuminate the scene while the seated girl on the left metal flight case smoothly leans into her signature relaxed pose—placing her left elbow onto her raised knee and resting her chin gently in her hand as her cyan-and-magenta hair settles softly around her shoulders—while the wet floor reflections brighten and background aurora lights drift slowly. Crisp anime illustration style, smooth natural settle, zero morphing or jitter.
```

---

## BLOQUE 2 — Prompts para Movimiento en Cabina / Idle (`cabina_menu_loop`)

### Opción 2A (Recomendada): Loop principal natural y expresivo
- **Cómo usarlo:** Adjunta `assets/menu/background/cabina_aurora_menu.png` como **imagen inicial / referencia** (si te deja poner mismo First y Last Frame, úsala en ambos para lograr un bucle perfecto sin salto).

```text
Seamless looping 2D anime game main menu background animation based exactly on the attached illustration. Strictly locked-off static tripod camera: zero camera movement, zero pan, zero zoom, zero shake. Keep the arcade cabinet geometry, the "AURORA" marquee, the center screen, the magenta "JUGAR" button, and the right-side "CREAR", "OPCIONES", and "SALIR" panels completely crisp, fixed, and undistorted. The anime girl remains comfortably seated in her exact position on the left metal flight case with her right sneaker planted firmly on the floor: she blinks naturally every few seconds, breathes gently in her chest and shoulders, gives a very subtle and smooth rhythmic head sway to the music while her chin rests lightly on her hand, and her long gradient dark-purple, cyan, and magenta hair ripples softly in a gentle breeze. Subtle breathing neon pulse on her headphone star emblem and sneaker sole. In the background, the aurora borealis ribbons drift slowly across the night sky, the distant concert crowd on the right sways softly with glowing cyan and magenta lightsticks, and neon reflections shimmer subtly on the wet floor. High-fidelity anime aesthetic, smooth seamless loop returning cleanly to the exact starting frame, no sudden jerks, no face distortion, no garbled text.
```

---

### Opción 2B: Loop un poco más musical / con ritmo en pie y hombros
- **Cómo usarlo:** Adjunta `assets/menu/background/cabina_aurora_menu.png`. Ideal si quieres que se note más claramente que está escuchando música frente a la cabina sin verse exagerada.

```text
Seamless looping 2D anime rhythm-game lobby animation, strictly locked-off static camera, zero camera drift, all UI buttons ("JUGAR", "CREAR", "OPCIONES", "SALIR") and cabinet typography locked in exact pixel position without flicker or morphing. Keep the anime girl seated solidly on the metal flight case on the left foreground, maintaining her hand-on-chin pose and grounded body silhouette. Add calm, natural musical life: gentle rhythmic shoulder and head groove synced to a relaxed beat, occasional natural eye blink, soft breeze flowing through the cyan and pink ends of her hair and loose jacket straps, subtle toe-tap impulse in her chunky glowing-sole sneaker without sliding off the floor, and soft ambient glow pulsing on her star headphones and cabinet neon edges. Crowd silhouettes in the lower right gently wave neon glowsticks, subtle aurora shimmer in the dark starry sky, soft light reflections rippling lightly across the wet venue floor. Smooth loopable motion, clean crisp anime art style.
```

---

### Opción 2C: Loop ultra-sutil (máxima estabilidad si la IA deforma rostro o textos)
- **Cómo usarlo:** Adjunta `assets/menu/background/cabina_aurora_menu.png`. Reduce el desplazamiento corporal al mínimo para evitar cualquier artefacto visual.

```text
Ultra-subtle seamless loop anime live-wallpaper animation of the exact attached image. Completely locked static camera, frozen UI elements, crisp unchanged typography on all signs and buttons. The girl sits completely anchored on the flight case in her exact pose with minimal motion: natural soft eye blinks, barely perceptible chest breathing, gentle floating drift only in the loose long strands of her cyan-pink hair and jacket edge, plus subtle ambient neon light shimmer. In the far background, the distant crowd lightsticks sway slowly, the aurora sky glows softly, and faint neon reflections pulse smoothly on the wet floor. Keep face, hands, headphones, and cabinet lines razor-sharp with zero deformation or morphing.
```

---

### Opción 2D (Avanzada / Fondo Verde): Solo la chica sentada para mantener el fondo original 100% intacto
- **Cómo usarlo:** Adjunta `assets/menu/character/aurora_girl_sit_idle.png`. Útil solo si prefieres editar o componer tú mismo al personaje sobre `cabina_aurora_menu_bg.png` en After Effects / CapCut / Premiere.

```text
Locked-off static character animation on a solid flat chroma-key bright green background (#00FF00), preserving the exact anime illustration style, lighting, colors, and proportions of the attached seated character (dark streetwear jacket with neon star patches, glowing cyan-magenta headphones, gradient cyan-pink hair, dark cargo pants, chunky glowing sneaker). She remains seated in the exact same spot with natural eye blinks, soft rhythmic head tilt while resting her chin on her hand, gentle breathing, and smooth flowing movement in her long trailing hair. Keep her hand, torso, and grounded sneaker anchored without sliding, clean sharp outline against flat green screen, no cast shadow on background, seamless loop.
```

---

## Recomendación rápida de prompts negativos / restricciones (si tu interfaz tiene campo "Negative prompt" o cosas a evitar)

Si el generador que usas tiene caja separada para lo que **NO** debe hacer, pega esto:

```text
camera movement, zoom, pan, tilt, handheld shake, morphing text, distorted typography, garbled letters, changing UI layout, deformed face, extra fingers, extra limbs, missing leg in walking shots, sudden teleporting, jerky frame jumps, flickering neon chaos, photorealistic style change, 3D CGI look
```

*(Si no tiene caja separada, los prompts de arriba ya traen las restricciones integradas.)*

---

## Flujo rápido recomendado para probar

1. **Primero genera el Loop (`2A` o `2C`)** con `cabina_aurora_menu.png` para confirmar que la cámara, la cara y los botones se mantengan estables.
2. **Luego genera la Intro (`1A`)** usando `cabina_aurora_menu_bg.png` como primer frame y `cabina_aurora_menu.png` como último frame.
3. Si te gustan los `.mp4`, conviértelos directo con:
   ```powershell
   .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\intro.mp4" -Role intro
   .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\loop.mp4" -Role loop
   ```
4. Vuelve a ejecutar el juego en Godot y `CabinaMenu.gd` los enlazará solos sin que tengas que cambiar nada de código.
