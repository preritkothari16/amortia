class_name GenomeRules
extends Resource
## Ranges, budget and mutation settings for genomes (GDD 5.3-5.4), plus how stat genes turn
## into real numbers. Edit data/genome_rules.tres, not this file.

@export_group("Stat genes")
## Lowest and highest value of each stat gene (speed, health, vision, ferocity).
@export var stat_min: float = 1.0
@export var stat_max: float = 10.0
## The "average" stat value: a gene here gives exactly the archetype's base value.
@export var stat_neutral: float = 5.0

@export_group("Stat budget")
## Budget at the first wave of a zone: points to spend over the four stat genes. 20 = four
## neutral genes (5 each), so an average enemy equals the archetype's base values.
@export var budget_start: int = 20
## Budget grows by this much every wave...
@export var budget_per_wave: int = 1
## ...up to this cap.
@export var budget_max: int = 32

@export_group("Gene -> value")
## Each stat point above / below neutral changes the base value by this fraction.
@export var speed_per_point: float = 0.10
@export var health_per_point: float = 0.15
@export var vision_per_point: float = 0.10
## Ferocity: each point above / below neutral changes melee damage by this fraction (gene 10 =
## x1.40, gene 1 = x0.68) and shortens / lengthens the attack cooldown by this fraction
## (gene 10 = x0.80, gene 1 = x1.16). At gene 10 damage per second is x1.75 - the same gain as
## health at gene 10 - so ferocity is no cheaper than health.
@export var ferocity_damage_per_point: float = 0.08
@export var ferocity_cooldown_per_point: float = 0.04
## The cooldown never gets shorter than this many seconds.
@export var attack_cooldown_min: float = 0.5

@export_group("Terrain adaptation budget")
## Sum of the five terrain genes (swimmer, climber, crawler, toxin_resistance, night_sense) may
## not exceed this (GDD 5.3: 1.5 - forces specialisation). Separate from the stat budget, and a
## ceiling only: unlike stat points, adaptations don't have to be spent.
@export var adaptation_budget: float = 1.5
## A random (wave 1) genome spends a random amount between 0 and this on adaptations.
## Default = the full budget, so evolution has variation to select from in every zone.
@export var adaptation_random_max: float = 1.5
## Size (standard deviation) of the Gaussian nudge for terrain genes.
@export var adaptation_sigma: float = 0.1

@export_group("Mutation")
## Chance for each gene to mutate.
@export_range(0.0, 1.0) var mutation_rate: float = 0.1
## Size (standard deviation) of the Gaussian nudge for stat genes and behaviour genes.
@export var stat_sigma: float = 1.0
@export var behaviour_sigma: float = 0.1


## Stat budget for a wave number (1 = first wave of the zone).
func budget_for_wave(wave: int) -> int:
	return mini(budget_start + budget_per_wave * maxi(wave - 1, 0), budget_max)
