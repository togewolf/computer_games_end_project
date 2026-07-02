extends Wizard

@onready var agent_timer = Timer.new()
@onready var speed_slider = $"../SpeedSlider"
@onready var randomness_slider = $"../RandomnessSlider"

# Determines how precise our wizard can aim to its target location.
var jitter_radius = 128.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Setup Agent AI Timer
	add_child(agent_timer)
	self.is_player = false
	agent_timer.timeout.connect(_agent_ai_tick)
	agent_timer.start(speed_slider.value)
	speed_slider.value_changed.connect(func(val): agent_timer.wait_time = val)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	pass


func _agent_ai_tick():
	var element_to_cast = _calculate_agent_move()
		
	# Apply randomness slider logic
	if randf() < randomness_slider.value:
		element_to_cast = randi() % 4 as Globals.Element

	# Determine where we want to aim
	var target_location = opponent.global_position

	# Spell weaving
	var jitter_angle    = randf() * 360
	var jitter_distance = randf() * jitter_radius
	var aim_position    = target_location + Vector2.from_angle(jitter_angle) * jitter_distance
	
			
	self.cast_spell(element_to_cast, aim_position)


func _calculate_agent_move() -> Globals.Element:
	var all_projectiles = get_tree().get_nodes_in_group("projectiles")
	var incoming = []
	var outgoing = []
	
	for p in all_projectiles:
		if p.is_player_owned: incoming.append(p)
		else: outgoing.append(p)
		
	# Sort by distance to Agent (X axis assumption)
	incoming.sort_custom(func(a, b): return a.global_position.x > b.global_position.x)
	outgoing.sort_custom(func(a, b): return a.global_position.x > b.global_position.x)
	
	# Find the first incoming spell that isn't countered by our outgoing spells
	for i in range(incoming.size()):
		var inc_spell = incoming[i]
		
		# If we have a matching outgoing spell in the same index
		if i < outgoing.size():
			var out_spell = outgoing[i]
			# If our outgoing spell beats or annihilates the incoming, we are safe here
			if out_spell.element == inc_spell.element or Globals.BEATS[out_spell.element] == inc_spell.element:
				continue # Handled, look at the next incoming spell
				
		# We found an un-countered spell! Return the perfect counter.
		return Globals.get_counter_for(inc_spell.element)

	# Default action if no threats exist: pick randomly or cast a default
	return randi() % 4 as Globals.Element
