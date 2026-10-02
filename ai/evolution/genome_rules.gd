class_name GenomeRules
extends Resource
## Ranges, budget and mutation settings for genomes (GDD 5.3-5.4), plus how stat genes turn
## into real numbers. Edit data/genome_rules.tres, not this file.

@export_group("Stat genes")
## Lowest and highest value of each stat gene (speed, health, vision).
@export var stat_min: float = 1.0
@export var stat_max: float = 10.0
## The "average" stat value: a gene here gives exactly the archetype's base value.
@export var stat_neutral: float = 5.0

@export_group("Stat budget")
## Budget at the first wave of a zone (sum of all stat genes may not exceed it).
@export var budget_start: int = 15
## Budget grows by this much every wave...
@export var budget_per_wave: int = 1
## ...up to this cap.
@export var budget_max: int = 24

@export_group("Gene -> value")
## Each stat point above / below neutral changes the base value by this fraction.
@export var speed_per_point: float = 0.10
@export var health_per_point: float = 0.15
@export var vision_per_point: float = 0.10

@export_group("Mutation")
## Chance for each gene to mutate.
@export_range(0.0, 1.0) var mutation_rate: float = 0.1
## Size (standard deviation) of the Gaussian nudge for stat genes and behaviour genes.
@export var stat_sigma: float = 1.0
@export var behaviour_sigma: float = 0.1


## Stat budget for a wave number (1 = first wave of the zone).
func budget_for_wave(wave: int) -> int:
	return mini(budget_start + budget_per_wave * maxi(wave - 1, 0), budget_max)
