extends Area2D
class_name Projectile

@export var speed: float = 100.0
var element: Globals.Element
var is_player_owned: bool = false
var direction: Vector2 = Vector2.UP

func _ready():
	# tint the sprite based on element. 
	# Or todo swap textures or instantiate completely different scenes here.
	match element:
		Globals.Element.WATER: modulate = Color(0.2, 0.5, 1.0)
		Globals.Element.FIRE: modulate = Color(1.0, 0.3, 0.2)
		Globals.Element.NATURE: modulate = Color(0.2, 0.8, 0.2)
		Globals.Element.LIGHT: modulate = Color(1.0, 1.0, 0.8)
		
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
		if area.is_player == self.is_player_owned: return # Don't hit self
		area.take_damage(10)
		queue_free()
