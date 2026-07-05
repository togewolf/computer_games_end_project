extends Area2D
class_name Wizard

signal health_changed(new_health)
signal mana_changed (new_mana)

@export var is_player: bool = true
@export var max_health: int = 100
@export var max_shield : int = 50
@export var max_mana   : float = 100
@export var movespeed  : float = 64
var opponent : Wizard;

var current_health: int
var current_shield: int
var current_mana  : float = max_mana
var mana_regen    : float = 2.0

var mana_timer = Timer.new()

var projectile_scene = preload("res://Projectile.tscn")

func _ready():
	current_health = max_health
	current_shield = 0
	current_mana   = max_mana
	add_child(mana_timer)
	mana_timer.timeout.connect(_add_mana)
	mana_timer.start(1)

func _add_mana():
	current_mana = clamp( current_mana + mana_regen, 0, max_mana )
	mana_changed.emit(current_mana)

func cast_spell(spell : Globals.SpellDescriptor, target_location : Vector2):
	var cost = Globals.get_spell_cost(spell);
	if ( cost > current_mana ): 
		print("Spell costs: ", cost, " but we only have ", current_mana )
		return

	current_mana -= cost
	mana_changed.emit(current_mana)

	var proj = projectile_scene.instantiate()
	proj.element = spell.element
	proj.caster = self
	proj.is_player_owned = is_player
	proj.speed = Globals.PROJECTILE_SPEED_SPEEDS[spell.speed]
	proj.mode = spell.mode
	proj.direction = (target_location - self.global_position).normalized()
	proj.position = $SpawnPoint.global_position
	get_tree().current_scene.add_child(proj)

func take_damage(amount: int):
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		print("Wizard Defeated!")
