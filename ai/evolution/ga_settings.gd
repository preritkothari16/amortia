class_name GASettings
extends Resource
## Genetic Algorithm configuration (GDD 5.4). Edit data/ga.tres, not this file.

## Genomes in each new generation (GDD: 20 per archetype per wave).
@export var population_size: int = 20
## Genomes drawn per tournament; the fittest of them becomes a parent.
@export var tournament_size: int = 3
## The best this-many genomes are copied unchanged into the next generation.
@export var elitism: int = 2
## Chance that a child is made by uniform crossover (otherwise it copies parent A).
@export_range(0.0, 1.0) var crossover_rate: float = 0.9
## Chance per gene to mutate.
@export_range(0.0, 1.0) var mutation_rate: float = 0.1

@export_group("Diversity guard")
## If more than this share of the population has the same path_mode...
@export_range(0.0, 1.0) var diversity_threshold: float = 0.8
## ...the mutation rate is multiplied by this for that one generation.
@export var diversity_mutation_multiplier: float = 2.0
