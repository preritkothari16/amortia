class_name BehaviourWeights
extends Resource
## Behaviour genes (GDD 5.3): how much an enemy cares about each kind of action, 0..1.
## They multiply the utility scores, so the Genetic Algorithm can later evolve tactics
## (charge vs flank vs patient hunter) by changing these numbers, not code.
## Caution and Cohesion are carried (and evolved by the genome) but no prototype action reads
## them yet - they come with later actions (Retreat, Hold for pack).

## Scales Chase: high = rushes a visible player.
@export_range(0.0, 1.0) var aggression: float = 0.6
## Scales Flank: high = circles round to the player's blind side when allies are attacking.
@export_range(0.0, 1.0) var flanking: float = 0.6
## Scales Investigate: high = follows up noises and old sightings, low = loses interest fast.
@export_range(0.0, 1.0) var patience: float = 0.6
## Not used yet (future Retreat action).
@export_range(0.0, 1.0) var caution: float = 0.5
## Not used yet (future Hold-for-pack action).
@export_range(0.0, 1.0) var cohesion: float = 0.5
