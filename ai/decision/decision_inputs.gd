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
## How provoking that lead was, 0..1 (1 = gunshot right next to us).
var lead_strength: float = 0.0
## How long the wave has dragged on, 0..1 (UtilitySettings.wave_pressure). Pulls even lazy
## enemies towards a lead they hold.
var wave_pressure: float = 0.0
## Packmates (allies within pack_radius that know about the player), without the enemy itself.
var pack_size: int = 0
## There is a packmate group to regroup with and a clear line to it (PackCoordination.anchor).
var regroup_available: bool = false
## This enemy already spent its regroup time budget for this chase (RegroupBudget).
var regroup_expired: bool = false
## Escort levels: the survivor is perceived right now (same sight rules as the player).
var survivor_visible: bool = false
## Distance (px) to the survivor. Only meaningful while survivor_visible.
var survivor_distance: float = INF
