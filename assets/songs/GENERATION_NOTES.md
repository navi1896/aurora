# Demo cover generation notes

Mode: OpenAI built-in image generation.

Style references:

- `res://assets/menu/reference/concept_asset_sheet.png`
- `res://assets/menu/reference/concept_full_menu.png`

Prompt set:

1. `aurora_demo.png`: cyan/violet crystal above a futuristic skyline with
   aurora curtains and equalizer-shaped lights.
2. `night_drive.png`: empty neon highway through a midnight city with wet
   pavement and a strong central vanishing point.
3. `pulse_grid.png`: abstract perspective rhythm grid with cyan, violet and
   magenta equalizer columns.

All covers were generated as square pixel-art images without text, logos or
characters. `res://tools/process_song_covers.gd` normalizes them to 512x512
using nearest-neighbor resizing.
