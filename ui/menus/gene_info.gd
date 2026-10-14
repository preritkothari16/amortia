class_name GeneInfo
extends RefCounted
## Player-facing words for the genome (UI only): full gene names, groups, what each gene does,
## trait words, survival tips and the route-strategy labels. Meanings checked against
## ai/evolution/genome.gd, ai/decision/behaviour_weights.gd and ai/evolution/fitness.gd.
## Caution, cohesion and the route strategy evolve but no behaviour reads them yet
## (behaviour_weights.gd, HANDOFF step 16), so the screens mark them and never promise effects.

## Group -> genes, in display order ("Show all").
const GROUPS: Array[Array] = [
	["Body", ["speed", "health", "vision"]],
	["Behaviour", ["aggression", "caution", "flanking", "cohesion", "patience"]],
	["Terrain", ["swimmer", "climber", "crawler", "night_sense"]],
	["Resistance", ["toxin_resistance"]],
]

const NAMES: Dictionary = {
	"speed": "Speed", "health": "Health", "vision": "Vision",
	"aggression": "Aggression", "caution": "Caution", "flanking": "Flanking",
	"cohesion": "Cohesion", "patience": "Patience",
	"swimmer": "Swimming", "climber": "Climbing", "crawler": "Crawling",
	"toxin_resistance": "Toxin resistance", "night_sense": "Night sense",
}

## What a gene does in the game (tooltips).
const MEANINGS: Dictionary = {
	"speed": "How fast it moves.",
	"health": "How many hits it takes.",
	"vision": "How far it can see you (walls block sight).",
	"aggression": "How eagerly it charges when it sees you.",
	"caution": "Evolves, but has no effect in the game yet.",
	"flanking": "How often it circles round to your side while others attack.",
	"cohesion": "Evolves, but has no effect in the game yet.",
	"patience": "How long it follows up noises and old sightings.",
	"swimmer": "Makes water cheaper to cross; high values open deep water.",
	"climber": "Makes fences cheaper to climb over.",
	"crawler": "Lets it crawl through vents.",
	"toxin_resistance": "Protects it in toxic pools, so it paths through them.",
	"night_sense": "Sees and hears better at night.",
}

## Genes no behaviour reads yet.
const INERT: Array[String] = ["caution", "cohesion"]

## Trait word when the gene is high / low (story chips, downed screen).
const TRAITS: Dictionary = {
	"speed": ["Fast", "Slow"], "health": ["Tough", "Fragile"], "vision": ["Sharp-eyed", "Short-sighted"],
	"aggression": ["Aggressive", "Timid"], "flanking": ["Flankers", "Head-on"],
	"patience": ["Relentless", "Easily distracted"], "swimmer": ["Swimmers", ""],
	"climber": ["Climbers", ""], "crawler": ["Crawlers", ""], "toxin_resistance": ["Toxin-proof", ""],
	"night_sense": ["Night hunters", ""],
}

## One tip per high gene (downed screen). Only genes that act in the game.
const TIPS: Dictionary = {
	"speed": "It closes distance fast: keep moving and shoot while backing off.",
	"health": "It soaks up hits: focus your fire on it first.",
	"vision": "It spots you from far away: break line of sight behind walls.",
	"aggression": "It charges straight in: sidestep and dodge through its rush.",
	"flanking": "It circles round while others attack: watch your sides.",
	"patience": "It follows up every noise: move after you shoot.",
	"swimmer": "Water won't slow it down: don't rely on rivers for safety.",
	"climber": "Fences won't stop it: don't hide behind them.",
	"crawler": "It can come through vents: keep an eye on them.",
	"toxin_resistance": "Toxic pools barely hurt it: don't lure it through them.",
	"night_sense": "It hunts well at night: use cover and keep moving after dark.",
}

## Route strategy gene (Genome.PathMode). Plain label, tooltip.
const PATH_MODES: Dictionary = {
	"FLOW": ["Shared route", "Flow field: follows the route map the whole pack shares."],
	"ASTAR": ["Own route", "A*: plans its own shortest path."],
	"GREEDY": ["Beeline", "Greedy: always steps toward you, even into dead ends."],
}
const PATH_MODE_NOTE: String = "Route strategy evolves, but movement doesn't use it yet."


static func gene_name(gene: String) -> String:
	return NAMES.get(gene, gene.capitalize())


static func is_stat(gene: String) -> bool:
	return Genome.STAT_GENES.has(StringName(gene))


static func is_inert(gene: String) -> bool:
	return INERT.has(gene)


## Gene value as 0..1 of its range (stats 1..10, the others 0..1).
static func normalized(gene: String, value: float) -> float:
	return clampf((value - 1.0) / 9.0, 0.0, 1.0) if is_stat(gene) else clampf(value, 0.0, 1.0)


## Change as a share of the gene's range (stats span 9, the others 1), so genes compare.
static func relative_delta(gene: String, delta: float) -> float:
	return delta / 9.0 if is_stat(gene) else delta


## Human value: "6.2" for stats, "62 %" for 0..1 genes.
static func format_value(gene: String, value: float) -> String:
	return "%.1f" % value if is_stat(gene) else "%d%%" % roundi(value * 100.0)


static func format_delta(gene: String, delta: float) -> String:
	return "%+.1f" % delta if is_stat(gene) else "%+d%%" % roundi(delta * 100.0)


## All genes in display order.
static func all_genes() -> Array[String]:
	var out: Array[String] = []
	for group: Array in GROUPS:
		for gene: String in group[1]:
			out.append(gene)
	return out


## How far a gene mean is from "average" (5 for stats, 0.5 for behaviour; terrain genes start
## at 0, so their own value). Signed: + = high.
static func deviation(gene: String, value: float) -> float:
	if is_stat(gene):
		return (value - 5.0) / 4.5
	if Genome.TERRAIN_GENES.has(StringName(gene)):
		return value
	return (value - 0.5) / 0.5


## Up to `count` genes that act in the game and stand out most, as [gene, word, deviation].
static func standout_traits(means: Dictionary, count: int = 3, threshold: float = 0.15) -> Array[Array]:
	var scored: Array[Array] = []
	for gene: String in TRAITS:
		if not means.has(gene):
			continue
		var d: float = deviation(gene, means[gene])
		var word: String = TRAITS[gene][0 if d > 0.0 else 1]
		if word != "" and absf(d) >= threshold:
			scored.append([gene, word, d])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return absf(a[2]) > absf(b[2]))
	return scored.slice(0, count)


## Genes sorted by the size of their change (relative to range), biggest first:
## [gene, before, after, delta]. include_inert = false leaves out genes with no effect.
static func ranked_changes(before: Dictionary, after: Dictionary, include_inert: bool = false) -> Array[Array]:
	var rows: Array[Array] = []
	for gene: String in all_genes():
		if not after.has(gene) or not before.has(gene) or (not include_inert and is_inert(gene)):
			continue
		rows.append([gene, before[gene], after[gene], after[gene] - before[gene]])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return absf(relative_delta(a[0], a[3])) > absf(relative_delta(b[0], b[3])))
	return rows


## A change is worth mentioning above ~1 % of the gene's range.
static func is_notable(gene: String, delta: float) -> bool:
	return absf(relative_delta(gene, delta)) >= 0.01


## One sentence about the new generation from its two biggest notable changes.
static func story_sentence(generation: int, changes: Array[Array]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: Array in changes:
		if parts.size() == 2 or not is_notable(row[0], row[3]):
			break
		parts.append(_direction_phrase(row[0], row[3]))
	if parts.is_empty():
		return "Generation %d is almost the same as the last one." % generation
	return "Generation %d is %s." % [generation, " and ".join(parts)]


## "What to expect": up to `count` short bullets from the biggest notable changes.
static func expectations(changes: Array[Array], count: int = 3) -> Array[String]:
	var out: Array[String] = []
	for row: Array in changes:
		if out.size() == count or not is_notable(row[0], row[3]):
			break
		out.append(_expect_line(row[0], row[3] > 0.0))
	if out.is_empty():
		out.append("About the same pack as last wave.")
	return out


static func _direction_phrase(gene: String, delta: float) -> String:
	var up: bool = delta > 0.0
	match gene:
		"speed": return "getting faster" if up else "slowing down"
		"health": return "getting tougher" if up else "getting more fragile"
		"vision": return "seeing further" if up else "seeing less far"
		"aggression": return "charging more" if up else "charging less"
		"flanking": return "flanking more" if up else "flanking less"
		"patience": return "searching longer" if up else "giving up sooner"
	return ("more" if up else "less") + " " + gene_name(gene).to_lower()


static func _expect_line(gene: String, up: bool) -> String:
	match gene:
		"speed": return "They reach you sooner." if up else "You get more time to aim."
		"health": return "Each one takes more hits." if up else "They go down in fewer hits."
		"vision": return "They spot you from further away." if up else "You can get closer unseen."
		"aggression": return "More of them rush straight at you." if up else "Fewer of them rush you."
		"flanking": return "Expect attacks from your sides." if up else "Fewer attacks from your sides."
		"patience": return "They chase noises for longer." if up else "They lose your trail sooner."
		"swimmer": return "Water slows them less." if up else "Water slows them more."
		"climber": return "Fences hold them back less." if up else "Fences hold them back more."
		"crawler": return "They use vents more." if up else "They use vents less."
		"toxin_resistance": return "Toxic pools hurt them less." if up else "Toxic pools hurt them more."
		"night_sense": return "They hunt better at night." if up else "They hunt worse at night."
	return "%s %s." % [gene_name(gene), "rises" if up else "drops"]


## Plain description of one genome for the downed screen, e.g.
## "a fast, tough Bloomed that rushes you head-on".
static func describe_plain(g: Genome) -> String:
	var means: Dictionary = {}
	for gene: String in all_genes():
		means[gene] = g.get(gene)
	var traits: Array[Array] = standout_traits(means, 2, 0.2)
	if traits.is_empty():
		return "an all-round Bloomed with no stand-out trait"
	var words: PackedStringArray = PackedStringArray()
	for t: Array in traits:
		words.append((t[1] as String).to_lower())
	return "a %s Bloomed" % ", ".join(words)


## The tip for a genome's strongest acting trait (or a general one).
static func tip_for(g: Genome) -> String:
	var means: Dictionary = {}
	for gene: String in all_genes():
		means[gene] = g.get(gene)
	for t: Array in standout_traits(means, 5, 0.2):
		if t[2] > 0.0 and TIPS.has(t[0]):
			return TIPS[t[0]]
	return "Keep moving and use walls to split the pack."
