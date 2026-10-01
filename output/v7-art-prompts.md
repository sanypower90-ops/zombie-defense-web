# V7 이미지 생성 기록

방식: 내장 imagegen. 투명 스프라이트는 Godot에서 개체 경계별로 분리합니다.

## grips_a

파일: game/assets/sprites/grips_a_v7.png

프롬프트:

Use case: stylized-concept. Transparent 4x4 equal-cell game sprite atlas. Exactly sixteen isolated upper-body survivor illustrations from helmet head down to WAIST ONLY, no legs. Same orange jacket, black helmet, gloves and backpack, gritty hand-painted isometric comic zombie survival style. Hands firmly attached to arms gripping the CORRECT weapon, no detached hands. Equal torso size in every cell, entire torso and weapon confined to central 60 percent of cell, wide transparent gutters. No labels text background grid or shadow. True alpha. Row-major cells 0,1,2: pistol FRONT, LEFT side, BACK. Cells3,4,5: pump shotgun FRONT, LEFT, BACK. Cells6,7,8: compact submachine gun FRONT, LEFT, BACK. Cells9,10,11: assault rifle FRONT, LEFT, BACK. Cells12,13,14: belt-fed heavy machine gun FRONT, LEFT, BACK. Cell15 empty transparent. Point weapons in facing direction; clearly different silhouettes. Keep heads and waist vertically aligned.

## grips_b

파일: game/assets/sprites/grips_b_v7.png

프롬프트:

Use case: stylized-concept. Transparent 4x4 equal-cell game sprite atlas. Exactly sixteen isolated upper-body survivor illustrations from helmet head down to WAIST ONLY, no legs. Same orange jacket, black helmet, gloves and backpack, gritty hand-painted isometric comic zombie survival style. Hands firmly attached to arms gripping the CORRECT weapon, no detached hands. Equal torso size in every cell, entire torso and weapon confined to central 60 percent of cell, wide transparent gutters. No labels text background grid or shadow. True alpha. Row-major cells0,1,2: drum grenade launcher FRONT, LEFT side, BACK. Cells3,4,5: flamethrower with fuel hose FRONT, LEFT, BACK. Cells6,7,8: long scoped sniper rifle FRONT, LEFT, BACK. Cells9,10,11: shoulder-held green rocket launcher FRONT, LEFT, BACK. Cells12,13,14: blue glowing futuristic laser cannon FRONT, LEFT, BACK. Cell15 empty transparent. Distinct gun silhouettes, no pistol in any cell. Heads and waist vertically aligned.

## melee_fx

파일: game/assets/sprites/melee_fx_v7.png

프롬프트:

Use case: stylized-concept. Transparent game effect atlas EXACT4x4 equal cells wide empty gutters. No body parts except gloves described. Row1 four animation stages of a luminous BLUE CYAN HALF-MOON sword slash, thin curved crescent sweeping left to right, no purple no explosion. Row2 four animation stages of an orange black GLOVED FIST moving to the RIGHT: solid clenched glove, bigger glove with motion trail, 50 percent bigger translucent glove with streaming afterimages, faint enlarged glove fading. Row3 four blue crescent stages mirrored, Row4 four fist stages pointing UP. Hand-painted comic game illustration, smooth dynamic luminous streaks. Entire effects inside central60percent eachcell. No text background grid or checkerboard. True transparency.

## ground

파일: game/assets/sprites/ground_v7.png

프롬프트:

Use case: stylized-concept. Seamlessly tiling square TOP-DOWN ground texture for a gritty illustrated zombie survival city. Worn dark charcoal asphalt and subtle dusty concrete wear, hairline cracks, tiny gravel, faded blue-gray patches and sparse moss in cracks. Moody cool teal navy shadows with restrained purple ambient tint. Hand-painted comic game texture, medium detail, low contrast so orange survivors, zombies and items stay readable. Uniform lighting, no perspective, no horizon, no objects, no road markings, no text, no large holes. Seamless matching edges, opaque texture filling whole square.

## 근접 효과 최종 편집

Use case: precise-object-edit. Edit supplied effect atlas. Preserve the 4 by 4 equal grid, subject order, blue half-moon slashes and orange glove fists. REMOVE the blue and orange fog/backdrop completely. Only actual sharp slash ribbons and glove outlines plus VERY tight tiny glow may remain; all space between effects must be fully transparent alpha ZERO. Shrink each entire effect to central 55 percent of its own cell, leaving completely clear transparent gutters. No colored rectangles, no haze outside each sprite, no shadows, no checkerboard. True transparent cutouts intended for game engine cropping. Preserve no-purple no-explosion design.

