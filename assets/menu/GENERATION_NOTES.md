# Menu asset generation notes

Mode: OpenAI built-in image generation with local chroma-key removal.

Approved references:

- `reference/concept_asset_sheet.png`
- `reference/concept_full_menu.png`

Prompt set:

1. Background: 16:9 neon city rooftop at night, cyan/violet aurora, layered
   skyline and wet pixel reflections; no logo, character, buttons or text.
2. Logo: exact uppercase `AURORA`, angular cyan-to-magenta pixel lettering,
   equalizer accents, underline and center diamond; logo only.
3. Character: static full-body music fan with dark hair, neon headphones,
   black hoodie and cyan/violet details; character only.
4. Normal button: empty dark navy pixel frame with a stepped violet border.
5. Selected button: empty dark navy pixel frame with a stepped cyan border.
6. Selector: one white right-pointing pixel arrow with cyan and navy edges.

The logo, character, button and selector generations used a flat green source
background. `res://tools/process_menu_assets.gd` removes that background,
trims the assets and writes the final PNG files used by Godot.
