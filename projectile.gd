extends Area2D
class_name Projectile

@export var speed: float = 100.0
var element: Globals.Element
var is_player_owned: bool = false
var caster    : Wizard = null
var dealt_dmg : bool = false
var direction: Vector2 = Vector2.UP

func _ready():
	# swap the sprite texture based on element (was: tint via modulate)
	match element:
		Globals.Element.WATER: $Sprite2D.texture = preload("res://assets/projectile_water.png")
		Globals.Element.FIRE: $Sprite2D.texture = preload("res://assets/projectile_fire.png")
		Globals.Element.NATURE: $Sprite2D.texture = preload("res://assets/projectile_nature.png")
		Globals.Element.LIGHT: $Sprite2D.texture = preload("res://assets/projectile_light.png")

	area_entered.connect(_on_area_entered)

func _process(delta):
	position += direction * speed * delta

func _on_area_entered(area):
	if area is Projectile:
		# Don't interact with own projectiles
		if area.is_player_owned == self.is_player_owned: return

		# Annihilate if equal
		if element == area.element:
			queue_free()
			area.queue_free()
		# Destroy the other if we beat it
		elif Globals.BEATS[element] == area.element:
			area.queue_free()
		# If we lose, do nothing here (the other projectile will destroy us)

	elif area.has_method("take_damage"): # It's a Wizard
		# Are we past the y axis?
		var min_y = min(caster.global_position.y, caster.opponent.global_position.y)
		var max_y = max(caster.global_position.y, caster.opponent.global_position.y)
		
		if (dealt_dmg || global_position.y < min_y || global_position.y > max_y):
			return
		
		if area.is_player == self.is_player_owned: return # Don't hit self
		area.take_damage(10)
		dealt_dmg = true
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
	pass # Replace with function body.
