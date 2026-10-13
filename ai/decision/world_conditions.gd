class_name WorldConditions
extends RefCounted
## Level-wide facts the senses depend on, shared by every enemy (EnemyContext.conditions).
## Plain data: the day/night cycle (world/events) writes it, Perception reads it.

## True during night (GDD 4.4: zones 1 and 3). Night lowers vision and sharpens hearing.
var is_night: bool = false
