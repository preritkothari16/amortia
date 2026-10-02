class_name UtilityAI
extends RefCounted
## The decision maker of one enemy (GDD 6.5). Scores every action, adds a momentum bonus to
## the current one, and picks the highest. An action must score above `idle_score` on its own
## to be considered at all; if none does, the enemy idles.
## Decides at a fixed rate (5 Hz by default), not every frame, plus on request when something
## important happens (e.g. the player comes into view).

var settings: UtilitySettings
var genes: BehaviourWeights
## The action being executed until the next decision.
var current: UtilityAction.Type = UtilityAction.Type.IDLE
## Raw scores from the last decision (without momentum), for debugging. Type -> score.
var last_scores: Dictionary[UtilityAction.Type, float] = {}
## How many times `current` has changed (for flicker measurements).
var switches: int = 0

## Fixed order matters only for ties: the earlier action wins, so results are deterministic.
var _actions: Array[UtilityAction] = [ChaseAction.new(), FlankAction.new(), InvestigateAction.new()]
## Seconds until the next scheduled decision.
var _timer: float = 0.0


## `phase` (0..1) staggers enemies so they don't all decide on the same frame.
func _init(utility_settings: UtilitySettings, behaviour: BehaviourWeights, phase: float = 0.0) -> void:
	settings = utility_settings
	genes = behaviour
	_timer = settings.decision_interval * clampf(phase, 0.0, 1.0)


## Advances the clock. Returns true when it is time to decide.
func tick(delta: float) -> bool:
	_timer -= delta
	if _timer > 0.0:
		return false
	_timer += settings.decision_interval
	if _timer <= 0.0:
		_timer = settings.decision_interval  # we fell far behind (e.g. a long frame): don't stack
	return true


## Make the next tick() decide straight away.
func request_decision() -> void:
	_timer = 0.0


## Scores all actions and switches to the best one. Returns the chosen action.
func decide(inputs: DecisionInputs) -> UtilityAction.Type:
	var best: UtilityAction.Type = UtilityAction.Type.IDLE
	var best_score: float = settings.idle_score
	if current == UtilityAction.Type.IDLE:
		best_score += settings.momentum_bonus
	last_scores[UtilityAction.Type.IDLE] = settings.idle_score
	for action: UtilityAction in _actions:
		var raw: float = action.score(inputs, genes, settings)
		last_scores[action.type] = raw
		var total: float = raw + (settings.momentum_bonus if action.type == current else 0.0)
		# Only actions worth doing on their own (raw score above idle) compete; momentum then
		# decides between them. So momentum never keeps a pointless or impossible action alive.
		if raw > settings.idle_score and total > best_score:
			best = action.type
			best_score = total
	if best != current:
		switches += 1
		current = best
	return current
