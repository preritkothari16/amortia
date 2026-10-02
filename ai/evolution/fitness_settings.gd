class_name FitnessSettings
extends Resource
## Weights and normalisation for F = wD*D + wP*P + wS*S + wO*O (GDD 5.4).
## Every term is raw / cap, clamped to 0..1. Edit data/fitness.tres, not this file.

@export_group("Weights")
@export var weight_damage: float = 0.4
@export var weight_pressure: float = 0.25
@export var weight_survival: float = 0.15
@export var weight_objective: float = 0.2

@export_group("Normalisation")
## D = damage dealt / this (HP). 50 = half the player's 100 HP counts as a perfect score.
@export var damage_cap: float = 50.0
## Distance (px) from the player that counts as "pressure". 64 px = 4 tiles (GDD).
@export var pressure_radius: float = 64.0
## P = pressure seconds / this. 0 = use the wave's duration (fraction of the wave spent close).
@export var pressure_cap_seconds: float = 0.0
## S = seconds alive / this. 0 = use the wave's duration (survivors score 1).
@export var survival_cap_seconds: float = 0.0
## O = objective points / this.
@export var objective_cap: float = 1.0
