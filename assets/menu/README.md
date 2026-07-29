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
