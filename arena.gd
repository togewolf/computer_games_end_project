extends Node2D

@onready var player = $WizardPlayer
@onready var agent = $WizardAgent  

@onready var player_hp_bar = $PlayerHP
@onready var agent_hp_bar = $AgentHP
@onready var speed_slider = $SpeedSlider
@onready var randomness_slider = $RandomnessSlider

@onready var agent_timer = Timer.new()

func _ready():
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.max_health
	player.health_changed.connect(func(hp): player_hp_bar.value = hp)
	
	agent_hp_bar.max_value = agent.max_health
	agent_hp_bar.value = agent.max_health
	agent.health_changed.connect(func(hp): agent_hp_bar.value = hp)

	# Setup Agent AI Timer
	add_child(agent_timer)
	agent_timer.timeout.connect(_agent_ai_tick)
	agent_timer.start(speed_slider.value)
	speed_slider.value_changed.connect(func(val): agent_timer.wait_time = val)

func _process(_delta):
	# Placeholder Input Detection (Replace with ML Keyword later)
	if Input.is_action_just_pressed("cast_water"): player.cast_spell(Globals.Element.WATER)
	elif Input.is_action_just_pressed("cast_fire"): player.cast_spell(Globals.Element.FIRE)
	elif Input.is_action_just_pressed("cast_nature"): player.cast_spell(Globals.Element.NATURE)
	elif Input.is_action_just_pressed("cast_light"): player.cast_spell(Globals.Element.LIGHT)

func _agent_ai_tick():
	var element_to_cast = _calculate_agent_move()
	
	# Apply randomness slider logic
	if randf() < randomness_slider.value:
		element_to_cast = randi() % 4 as Globals.Element
		
	agent.cast_spell(element_to_cast)

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
