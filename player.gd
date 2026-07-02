extends Wizard


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	self.position.x += direction * speed * delta
	pass
