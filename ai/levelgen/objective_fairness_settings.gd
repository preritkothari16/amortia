class_name ObjectiveFairnessSettings
extends Resource
## Thresholds for ObjectiveFairness (Reactive Survival V1). Edit data/objective_fairness.tres.
## Set from 200 Maple Hollow generator seeds (2026-10-18): near-cover share p05 0.62 / p50 0.74;
## spawns watching the least-exposed route 3: 13 %, 4: 39 %, 5: 40 %, 6: 9 %. So the check rejects
## the worst ~half for Stealth (5+ watchers) and the ~8 % with the least cover, not everything.

## A route cell counts as "near cover" if a concealing (tall grass) or sight-blocking tile lies
## within this many cells (Chebyshev distance).
@export var cover_radius_cells: int = 2
## Share of the entry -> exit walk that must be near cover.
@export_range(0.0, 1.0) var min_cover_ratio: float = 0.65
## Worst-case watcher: an enemy at a spawn marker that sees all around, by day, with the best
## vision gene (base 160 px x 1.5).
@export var watch_range_px: float = 240.0
## Route search cost of a cell seen by one watcher (in steps): high = avoid exposure first.
@export var exposure_penalty: float = 50.0
## Stealth: most spawn markers allowed to watch the least-exposed route.
@export var max_watching_spawns: int = 4
## Generator retries (next seeds in a fixed sequence) before keeping the original layout.
@export var max_attempts: int = 8
@export var seed_stride: int = 104729
