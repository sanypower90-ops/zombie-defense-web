# 2D Sprite Asset Specification

- Character atlas cell: 128 × 128 transparent PNG
- Atlas grid: 8 columns × 5 rows
- Shared foot baseline: y = 116
- Row 0: idle, 4 frames
- Row 1: walk, 8 frames
- Row 2: attack, 6 frames
- Row 3: hurt, 4 frames
- Row 4: death, 8 frames
- Characters: player + walker, runner, brute, armored, exploder, spitter, charger, toxic, screamer, shield, leaper, regenerator, nightmare, boss, final_boss
- weapons.png: 4 × 3 grid, 12 weapons
- items.png: 4 × 2 grid, 7 items
- street_props.png: 3 × 2 grid, 6 props

The downloadable sprite pack produced for this branch uses this exact layout. Keeping filenames and atlas coordinates unchanged allows later artwork replacement without changing gameplay code.
