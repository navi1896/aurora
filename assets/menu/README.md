# Aurora menu assets

All final assets used by Godot live in the visible folders below:

- `background/menu_background.png`: 1920x1080 full-screen background.
- `logo/aurora_logo.png`: transparent Aurora logo.
- `character/menu_character.png`: transparent static character.
- `buttons/button_normal.png`: reusable normal button frame.
- `buttons/button_selected.png`: reusable focused button frame.
- `ui/selector_arrow.png`: focused-button selector.
- `fonts/PressStart2P-Regular.ttf`: pixel font used by the menu.

The `_sources` folder contains the chroma-key generation outputs. Run the
following command from the project root after replacing one of those files:

```powershell
godot --headless --path . --script res://tools/process_menu_assets.gd
```

The `reference` folder keeps the two approved concept images. Both source-only
folders contain `.gdignore` so Godot does not import development references.


## Recursos externos y video para CabinaMenu

`CabinaMenu.gd` detecta y enlaza automáticamente recursos externos sin tocar la UI ni los botones:

1. **Video externo (`.ogv` Ogg Theora, sin audio porque el menú usa `MenuMusicManager`):**
   - `assets/menu/video/cabina_menu_intro.ogv` — video de entrada opcional (se reproduce una vez al abrir).
   - `assets/menu/video/cabina_menu_loop.ogv` — loop principal del menú (si existen ambos, reproduce `intro` y luego pasa a `loop`).
   - Para convertir cualquier `.mp4`, `.mov` o `.webm` generado externamente (por ejemplo desde Gemini/Veo u otra herramienta) con los parámetros `libtheora` seguros de Godot 4.8:
     ```powershell
     .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_video.mp4" -Role loop
     .\tools\import_menu_external_video.ps1 -InputVideo "RUTA\tu_intro.mp4" -Role intro
     ```
   - Si la opción de accesibilidad **Reducir movimiento** (`reduced_motion`) está activa, el menú oculta y pausa el video y muestra la pose estática.

2. **Reemplazo directo de capas PNG (resolución recomendada 1672x941 para fondo y PNG transparente para el personaje):**
   - Fondo sin personaje: `assets/menu/background/cabina_aurora_menu_bg.png`
   - Personaje sentado (ojos abiertos): `assets/menu/character/aurora_girl_sit_idle.png`
   - Personaje sentado (ojos cerrados para parpadeo, mismo tamaño y alineación que `idle`): `assets/menu/character/aurora_girl_sit_blink.png`
