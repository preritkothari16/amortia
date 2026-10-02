class_name AttackRingSettings
extends Resource
## Tuning for the attack ring (GDD 6.4). Edit data/attack_ring.tres, not this file.

## Number of positions around the player (evenly spaced, slot 0 points east).
@export var slot_count: int = 8
## Distance (px) of the slots from the player.
@export var slot_radius: float = 28.0
## How many slot holders may attack at once.
@export var max_attackers: int = 3
## Distance (px) from the player an attacker steps in to.
@export var attack_distance: float = 12.0
## Enemies without a slot hold on this outer ring (px).
@export var wait_radius: float = 60.0
## Seconds an attacker keeps its token before handing it to a waiting slot holder (0 = keep).
@export var token_duration: float = 2.5

@export_group("Eligibility")
## Join the ring when the flow cost to the player is at most this (about tiles of walking).
@export var engage_cost: float = 7.0
## Leave the ring when the flow cost rises above this. Must be > engage_cost (hysteresis).
@export var release_cost: float = 9.0

@export_group("Slot validity")
## A slot is usable only if its tile costs at most this to stand on (excludes fences, walls).
@export var max_slot_tile_cost: float = 2.0
## ...and its walking cost to the player is at most this (excludes slots behind a fence).
@export var max_slot_path_cost: float = 3.5
