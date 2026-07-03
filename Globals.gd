# Globals.gd
extends Node

enum Element { WATER, FIRE, NATURE, LIGHT }
enum ProjectileMode { PROJECTILE, TARGETED }
enum ProjectileSpeed { NORMAL, FASTER, FASTEST }

# Anything needed to describe a spell
class SpellDescriptor extends RefCounted:
	var element : Element
	var speed   : ProjectileSpeed
	var mode    : ProjectileMode

	func _init(e : Element, s : ProjectileSpeed, m : ProjectileMode):
		element = e
		speed = s
		mode  = m

# Anything needed to describe the intention of casting a spell
class SpellIntent extends RefCounted:
	var spell 			: SpellDescriptor
	var target          : Node2D

	func _init(_spell : SpellDescriptor, _target : Node2D):
		spell = _spell
		target = _target


# Defines what each element DEFEATS
const BEATS = {
	Element.WATER: Element.FIRE,
	Element.FIRE: Element.NATURE,
	Element.NATURE: Element.LIGHT,
	Element.LIGHT: Element.WATER
}

func get_best_response(element : Element) -> Element:
	match element:
		Element.WATER:
			return Element.LIGHT
		Element.FIRE:
			return Element.WATER
		Element.NATURE:
			return Element.FIRE
		Element.LIGHT:
			return Element.NATURE
	return element


const ELEMENT_SPELL_COST = {
	Element.WATER: 1.0,
	Element.FIRE: 1.0,
	Element.NATURE: 1.0,
	Element.LIGHT: 1.0
}

# Defines the mana cost multipliers per projectile mode
const PROJECTILE_MODE_COSTS = {
	ProjectileMode.PROJECTILE : 1.0,
	ProjectileMode.TARGETED   : 2.5
}

const PROJECTILE_SPEED_COSTS = {
	ProjectileSpeed.NORMAL : 1.0,
	ProjectileSpeed.FASTER : 1.5,
	ProjectileSpeed.FASTEST : 2.0
}

const BASE_MULTIPLIER = 1.0

func get_spell_cost(intent : SpellDescriptor) -> float:
	return ELEMENT_SPELL_COST[intent.element] * BASE_MULTIPLIER * PROJECTILE_MODE_COSTS[intent.mode] * PROJECTILE_SPEED_COSTS[intent.speed]
