class_name PlayerVisualSettings
extends Resource
## Sprite sheets and animation timing for the Forsaken Scientist (PlayerVisual). Edit
## data/player_visual.tres, not this file. Visual only: nothing here changes gameplay.
##
## Every sheet is a transparent PNG of 80x80 frames: columns = animation frames, rows =
## directions (E, SE, S, SW, W, NW, N, NE; gun arm: 16 rows from 11.25 deg in 22.5 deg steps).
## Layout and drawing rules: art_src/forsaken_scientist/MANIFEST.md. Until legs_walk, torso_idle
## and gunarm are all set, the player keeps its greybox shape.

@export_group("Required sheets")
## 6 x 8: one full stride.
@export var legs_walk: Texture2D
## 4 x 8: torso, head, coat and human left arm, breathing loop.
@export var torso_idle: Texture2D
## 4 x 16: rest, fire, recoil, settle.
@export var gunarm: Texture2D

@export_group("Optional sheets")
## 1 x 8. Missing = legs_walk frame 0.
@export var legs_idle: Texture2D
## 6 x 8, in step with legs_walk. Missing = torso_idle.
@export var torso_walk: Texture2D
## 4 x 8: noise-maker throw with the left hand.
@export var torso_throw: Texture2D
## 2 x 8: flinch when hit.
@export var torso_hurt: Texture2D
## 4 x 16: emissive cores, drawn over the gun arm.
@export var gunarm_glow: Texture2D
## 3 x 16 at the barrel tip.
@export var muzzle_flash: Texture2D
## 3 x 16, used when the weapon fires more than one pellet. Missing = muzzle_flash.
@export var muzzle_flash_shotgun: Texture2D
## 6 x 8: whole body. Missing = the normal layers keep running.
@export var roll: Texture2D
## 8 x 4 (E, S, W, N): whole body, last frame held.
@export var death: Texture2D
## 1 x 1: ground ellipse under the feet.
@export var shadow: Texture2D

@export_group("Simple look (until the layered sheets exist)")
## 4 x 1 frames of 80x80: full-body static poses E, S, W, N (feet on the pivot).
@export var simple_poses: Texture2D
## 3 x 1 muzzle-flash frames, drawn at the muzzle.
@export var simple_flash: Texture2D

@export_group("Timing")
## World px walked per full stride (one loop of legs_walk). Keeps the feet from sliding on mud.
@export var stride_length: float = 28.0
## Below this speed (px/s) the legs stand still.
@export var walk_threshold: float = 10.0
## Torso idle loop (4-frame breath: 2 fps = one breath every 2 s).
@export var idle_fps: float = 2.0
@export var throw_fps: float = 16.0
@export var hurt_fps: float = 12.0
## Gun arm fire / recoil / settle after a shot (frames 1..3).
@export var gun_fps: float = 24.0
@export var flash_fps: float = 30.0
@export var death_fps: float = 10.0
