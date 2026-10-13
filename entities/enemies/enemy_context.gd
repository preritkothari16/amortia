class_name EnemyContext
extends RefCounted
## Shared services every enemy uses, built once by main.gd and handed out by WaveManager.

var flow_field: FlowField
## One flow field per terrain-profile bucket (flow_field above = its base field).
var flow_fields: FlowFieldSet
## Attack slots around the player (null = enemies close in directly).
var attack_ring: AttackRing
## Budgeted, cached A* for investigation targets.
var path_queue: PathQueue
## The player node. Enemies may only read its position when they can perceive it.
var target: Node2D
## How genome genes turn into stats (null = enemies ignore genomes).
var genome_rules: GenomeRules
## Fitness evaluator; enemies read its settings (pressure radius) while recording.
var fitness: Fitness
## Sense rules (night, stealth) and level-wide conditions (is it night?). null = old rules:
## no night, no concealment.
var perception: PerceptionSettings
var conditions: WorldConditions
## Destructible tiles: enemies break barricades and open doors through it (null = they can't).
var terrain_health: TerrainHealth
