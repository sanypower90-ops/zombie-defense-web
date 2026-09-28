# Runtime 3D model slots

The PNG files under `assets/reference/` are concept/reference sheets, not 3D meshes.
To reproduce those looks in gameplay, supply rigged or static `.glb`/`.gltf` assets.
Recommended names:

- `player.glb`
- `zombie_walker.glb`, `zombie_runner.glb`, `zombie_brute.glb`, `zombie_armored.glb`, `zombie_exploder.glb`, `zombie_boss.glb`
- `weapon_pistol.glb`, `weapon_shotgun.glb`, `weapon_smg.glb`, `weapon_rifle.glb`, `weapon_lmg.glb`, `weapon_grenade.glb`, `weapon_flamethrower.glb`, `weapon_sniper.glb`, `weapon_rocket.glb`, `weapon_laser.glb`
- environment props such as `car.glb`, `barrier.glb`, `crate.glb`, etc.

Current build deliberately uses lightweight procedural meshes so Web export works without external 3D assets.
