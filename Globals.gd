# Globals.gd
extends Node

enum Element { WATER, FIRE, NATURE, LIGHT }
enum ProjectileMode { SIMPLE, LOCATION, TARGETED }

# Defines what each element DEFEATS
const BEATS = {
	Element.WATER: Element.FIRE,
	Element.FIRE: Element.NATURE,
	Element.NATURE: Element.LIGHT,
	Element.LIGHT: Element.WATER
}

# Defines the mana cost multipliers per projectile mode
const PROJECTILE_MANA_COSTS = {
	ProjectileMode.SIMPLE : 1.0,
	ProjectileMode.LOCATION : 1.25,
	ProjectileMode.TARGETED : 2.5
}

# Helper to find the optimal counter
func get_counter_for(element: Element) -> Element:
	for key in BEATS:
		if BEATS[key] == element:
			return key
	return Element.WATER
