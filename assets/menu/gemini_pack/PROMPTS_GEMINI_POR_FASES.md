# Paquete por Fases para Generar Video en Gemini Web — Menú Principal de Aurora

Este paquete ya incluye las **3 imágenes corregidas (con ambas piernas y tenis completos)** y los prompts listos para trabajar **por fases** desde el navegador en **Gemini**:

1. `01_personaje_solo.png` — Personaje aislado en PNG transparente (anatomía completa: ambas piernas, pantorrillas y ambos tenis neon).
2. `02_menu_completo_con_personaje.png` — Escena 16:9 completa con el personaje ya corregido sentado frente a la cabina y los botones (`JUGAR`, `CREAR`, `OPCIONES`, `SALIR`).
3. `03_fondo_sin_personaje.png` — Escenario 16:9 limpio sin personaje.

> **Nota sobre Gemini en navegador:** Gemini Web no puede abrir archivos locales de tu PC por ruta escrita; en cada fase solo **arrastra o adjunta la imagen indicada abajo** junto con su prompt. Los prompts vienen en inglés porque Gemini/Veo obedece con mayor precisión las reglas de cámara fija y tipografía intacta.

---

## FASE 1 — Video Idle / Movimiento sentada frente a la cabina (Empieza por aquí)

**Objetivo de la fase:** Quedar 100% convencido del movimiento natural de la chica sentada y el ambiente antes de pasar a la animación inicial.  
**Imagen que subes en Gemini Web:** `02_menu_completo_con_personaje.png`

### Prompt 1A (Recomendado — Natural, fluido y equilibrado)
```text
Seamless looping 2D anime game main menu background animation based strictly on the attached illustration. Locked-off static wide tripod camera with zero camera movement, zero pan, zero zoom, and zero shake. Keep the arcade cabinet, the "AURORA" logo, center monitor screen, magenta "JUGAR" button, and right-side "CREAR", "OPCIONES", and "SALIR" panels completely fixed, sharp, and undistorted in their exact screen coordinates. Keep the anime girl comfortably seated on the left metal flight case with both complete legs and both cyan-soled chunky platform sneakers firmly planted on the floor without sliding: she blinks naturally every few seconds, breathes gently in her chest and shoulders, gives a soft relaxed rhythmic head sway while resting her chin in her hand, and her long dark-indigo hair with cyan and magenta tips ripples gently in a light breeze. Subtle breathing neon glow on her headphone emblem and sneaker soles. In the background, aurora ribbons drift slowly across the starry sky, the distant crowd on the right sways softly with cyan and magenta glowsticks, and wet floor reflections shimmer subtly. Crisp anime line art, smooth continuous loop, zero facial distortion, zero garbled text.
```

### Prompt 1B (Variante más rítmica — si en 1A se mueve demasiado poco)
```text
Seamless looping 2D anime rhythm-game lobby animation matching the exact attached image. Strictly locked static camera, zero drift, all cabinet lights and UI buttons ("JUGAR", "CREAR", "OPCIONES", "SALIR") locked in exact pixel position with crisp unchanged text. The seated girl keeps her body anchored on the flight case with both legs and both sneakers grounded on the floor, showing gentle musical shoulder and head groove, occasional natural blinks, flowing hair breeze in her cyan-pink ends, and subtle ambient pulse on her glowing headphones and sneaker soles. Distant crowd lightsticks sway smoothly on the lower right, aurora sky flows slowly overhead, soft neon floor reflections ripple calmly. Clean anime style, smooth natural rhythm.
```

### Prompt 1C (Variante ultra-sutil — si la IA llega a deformar cara o textos)
```text
Ultra-subtle seamless loop live-wallpaper animation of the exact attached 2D anime menu screen. Completely locked static camera, frozen UI layout and sharp untouched typography. The seated character keeps both legs and sneakers anchored solidly with only minimal organic life: gentle eye blinks, subtle chest breathing, faint breeze drifting through the long loose magenta-cyan strands of her hair, and soft ambient neon light shimmer. In the background, distant glowsticks sway slowly and aurora sky glows softly. Zero face warping, zero morphing.
```

*(Extra opcional 1D — solo si quisieras animar el personaje en fondo neutro aparte usando `01_personaje_solo.png`:)*
```text
Locked-off static character animation on a flat uniform dark slate studio backdrop (#121626), preserving the exact anime design, clothes, glowing headphones, and both complete legs and chunky cyan-soled sneakers of the attached character. Natural blinking, calm chest breathing, subtle rhythmic head sway resting her chin on her hand, and gentle flowing hair strands while both feet remain planted cleanly without sliding. Smooth loop.
```

---

## FASE 2 — Animación Inicial / Entrada al Menú (Cuando ya estés convencido con Fase 1)

**Objetivo de la fase:** Generar el clip inicial de entrada para que aparezca/se acomode frente a la cabina antes de pasar al bucle de Fase 1.

### Prompt 2A (Si tu interfaz de Gemini te permite subir **2 imágenes**: Inicio + Fin)
- **Imagen de inicio (First Frame):** `03_fondo_sin_personaje.png`
- **Imagen final (Last Frame):** `02_menu_completo_con_personaje.png`

```text
2D anime rhythm-game menu opening intro transition from the empty illuminated stage to the final seated illustration. Strictly locked-off static tripod camera with zero pan, zero zoom, zero shake, keeping the "AURORA" cabinet, "JUGAR" button, and "CREAR", "OPCIONES", "SALIR" panels completely fixed and sharp. Neon lights on the cabinet and wet floor power on brightly as the cyan-and-magenta anime girl (wearing glowing star headphones, oversized black streetwear jacket, dark cargo joggers, and both complete legs with matching chunky cyan-soled sneakers) walks casually in from the left along the wet floor, turns naturally toward the metal flight case on the bottom left, sits smoothly onto the corner of the crate, places both sneakers firmly on the floor, and rests her left elbow on her raised knee with her chin in her hand, matching the exact final pose and composition. Smooth natural timing, crisp anime art, zero morphing text.
```

### Prompt 2B (Si Gemini Web solo te deja subir **1 imagen** — sube `02_menu_completo_con_personaje.png`)
- **Ventaja:** Muy estable en navegador porque mantiene al 100% los textos, la cabina y a la chica con ambas piernas ya completas, haciendo un encendido de escena y acomodo inicial natural.

```text
2D anime rhythm-game title screen opening intro based on the attached image. Locked-off static wide tripod camera with zero pan, zero zoom, and zero camera shake; keep all UI panels ("AURORA", "JUGAR", "CREAR", "OPCIONES", "SALIR") completely fixed and legible. Starting from dimmed stage lighting, the cabinet neons, aurora sky, and wet floor reflections smoothly power up and bloom into full brightness while the seated anime girl on the left flight case (with both complete legs and both cyan-soled sneakers planted cleanly on the floor) settles smoothly from looking slightly toward the glowing cabinet screen into her relaxed menu pose—blinking warmly, turning her head slightly toward the viewer with a subtle calm smile, resting her chin in her hand as her long cyan-and-magenta hair settles gently over her shoulders. Crisp anime style, clean lines, smooth lighting wake-up.
```

### Prompt 2C (Si Gemini Web te permite adjuntar **2 imágenes de referencia a la vez**: `03_fondo_sin_personaje.png` + `01_personaje_solo.png`)
```text
2D anime game lobby intro combining the attached arcade stage background and the attached two-legged seated character. Locked static tripod camera, zero camera movement, all cabinet buttons and text crisp and fixed. Stage neon lights power up on the wet floor while the anime girl (exact jacket, star headphones, dark cargo pants, and both complete chunky cyan-soled sneakers) walks smoothly in from the left foreground, sits naturally onto the left metal flight case facing slightly right, plants both feet solidly on the reflective floor, and rests her chin comfortably in her hand. Subtle distant crowd glowsticks and flowing aurora sky, smooth anime animation, zero text distortion.
```

---

## FASE 3 — Integración rápida en Aurora (cuando ya apruebes ambos videos)

Una vez que tengas tus `.mp4` aprobados de Fase 1 y Fase 2, ejecuta en PowerShell dentro de `E:\Games\Projects\Aurora`:

```powershell
# Video de entrada (Fase 2) — opcional
.\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_video_fase2_intro.mp4" -Role intro

# Video en bucle continuo frente a la cabina (Fase 1)
.\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_video_fase1_loop.mp4" -Role loop
```

El script convierte todo automáticamente a `.ogv` (`assets/menu/video/`) con los parámetros compatibles de Godot 4.8 y `CabinaMenu.gd` los carga al instante conservando botones, brillos y accesibilidad intactos.
