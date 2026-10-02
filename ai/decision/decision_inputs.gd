class_name DecisionInputs
extends RefCounted
## Everything the utility AI is allowed to know, as plain values. The enemy scene fills this
## in from its senses; the scorers only read it. This is the "Sensors" side of the agent.

## Player seen (or sensed up close) right now.
var player_visible: bool = false
## Distance (px) to the player. Only meaningful while player_visible.
var distance_to_player: float = INF
## Where the player is looking relative to us: 1 = straight at us, -1 = back turned.
## Only meaningful while player_visible.
var player_facing_dot: float = 1.0
## Nearby allies whose current action is Chase.
var allies_chasing: int = 0
## A usable flank point exists (see FlankPlanner).
var flank_point_available: bool = false
## There is an unchecked last known position (a noise, or where the player was last seen).
var has_lead: bool = false
## Seconds since that lead was updated.
var lead_age: float = 0.0
