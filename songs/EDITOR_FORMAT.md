# Aurora Level Editor

The in-game editor stores creator projects under:

`user://aurora_editor/<project_name>/`

Each saved project contains:

- `project.json`: title, artist, BPM, difficulty, key count, media paths, and editor state.
- `chart.json`: the gameplay-ready note list.
- Imported media is copied to `user://aurora_editor/media/`; the original source file is never modified.

## Supported media

- Required video: select `.ogv`, `.mp4`, `.mov`, `.mkv`, `.webm`, `.avi`, or `.m4v`.
  Aurora uses `.ogv` directly and converts the other formats to an internal Ogg Theora copy.
  The original file is never modified. The official Windows package includes a compatible
  portable FFmpeg runtime, so the creator does not need to install it separately.
- Optional separate audio: `.mp3`, `.ogg`, or `.wav`.

Aurora performs the required conversion automatically; creators do not need to prepare OGV files
manually. Audio-only levels can use MP3, OGG, or WAV without a video.

## Note format

```json
{
  "time": 3.250,
  "lane": 1,
  "duration": 0.000
}
```

- `time`: note start in seconds.
- `lane`: zero-based lane index.
- `duration`: `0` for a tap; `0.18` seconds or longer for a hold.

Older tap-only charts remain compatible because a missing duration is treated as `0`.

## Hold-note rules

- Missing the initial press is a MISS.
- Releasing before 50% is a MISS.
- Releasing after 50% but far from the tail grants the minimum GOOD reward.
- Releasing near the tail is judged with the PERFECT, GREAT, and GOOD timing windows.
- Holding too far beyond the tail automatically resolves as the minimum GOOD reward so a chart cannot remain stuck.
