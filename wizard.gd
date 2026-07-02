extends Area2D
class_name Wizard

signal health_changed(new_health)

@export var is_player: bool = true
@export var max_health: int = 100
var current_health: int

var projectile_scene = preload("res://Projectile.tscn")

func _ready():
	current_health = max_health

func cast_spell(element: Globals.Element):
	var proj = projectile_scene.instantiate()
	proj.element = element
	proj.is_player_owned = is_player
	proj.direction = Vector2.UP if is_player else Vector2.DOWN
	proj.position = $SpawnPoint.global_position
	get_tree().current_scene.add_child(proj)

func take_damage(amount: int):
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		print("Wizard Defeated!")
