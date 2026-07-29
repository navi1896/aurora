# Aurora songs

Aurora 1.0 is distributed without songs. Content created in the in-game editor
is stored in the player's Godot user-data folder and appears in the song
library automatically.

Developers may also add a `.tres` `SongData` resource while working on the
project. A song can provide a cover, audio or background video, preview timing,
BPM and one or more `ChartData` resources.

Charts can point to a JSON file through `ChartData.chart_path`. Aurora accepts
notes expressed in seconds or musical beats:

```json
{
  "version": 1,
  "offset_seconds": 1.5,
  "notes": [
    { "beat": 0.0, "lane": 0 },
    { "beat": 1.0, "lane": 1 },
    { "time": 3.25, "lane": 2 }
  ]
}
```

`lane` starts at zero. Optional `duration` and `length_beats` values create
hold notes. A public song must have playable media and at least one valid,
non-empty chart; incomplete drafts stay out of the playable library instead of
silently receiving generated practice notes.
