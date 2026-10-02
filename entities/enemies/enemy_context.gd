class_name EnemyContext
extends RefCounted
## Shared services every enemy uses, built once by main.gd and handed out by WaveManager.

var flow_field: FlowField
## Attack slots around the player (null = enemies close in directly).
var attack_ring: AttackRing
## Budgeted, cached A* for investigation targets.
var path_queue: PathQueue
## The player node. Enemies may only read its position when they can perceive it.
var target: Node2D
## How genome genes turn into stats (null = enemies ignore genomes).
var genome_rules: GenomeRules
