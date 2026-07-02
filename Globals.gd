# Globals.gd
extends Node

enum Element { WATER, FIRE, NATURE, LIGHT }

# Defines what each element DEFEATS
const BEATS = {
	Element.WATER: Element.FIRE,
	Element.FIRE: Element.NATURE,
	Element.NATURE: Element.LIGHT,
	Element.LIGHT: Element.WATER
}

# Helper to find the optimal counter
func get_counter_for(element: Element) -> Element:
	for key in BEATS:
		if BEATS[key] == element:
			return key
	return Element.WATER
