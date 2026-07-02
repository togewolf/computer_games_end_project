extends Area2D
class_name Wizard

signal health_changed(new_health)

@export var is_player: bool = true
@export var max_health: int = 100
@export var max_shield : int = 50
@export var max_mana   : int = 100
@export var speed      : float = 64
var opponent : Wizard;

var current_health: int
var current_shield: int
var current_mana  : int

var projectile_scene = preload("res://Projectile.tscn")

func _ready():
	current_health = max_health
	current_shield = 0
	current_mana   = max_mana

func cast_spell(element: Globals.Element, target_location : Vector2):
	var proj = projectile_scene.instantiate()
	proj.element = element
	proj.is_player_owned = is_player	
	proj.direction = (target_location - self.global_position).normalized()
	proj.position = $SpawnPoint.global_position
	get_tree().current_scene.add_child(proj)

func take_damage(amount: int):
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		print("Wizard Defeated!")
