extends Node2D

@onready var player = $WizardPlayer
@onready var agent = $WizardAgent  

@onready var player_hp_bar = $PlayerHP
@onready var agent_hp_bar = $AgentHP
@onready var voice_manager = $VoiceManager 

func _ready():
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.max_health
	player.health_changed.connect(func(hp): player_hp_bar.value = hp)
	player.opponent = agent;
	
	agent_hp_bar.max_value = agent.max_health
	agent_hp_bar.value = agent.max_health
	agent.health_changed.connect(func(hp): agent_hp_bar.value = hp)
	agent.opponent = player;

	voice_manager.voice_command_received.connect(_handle_voice_cast)

func _process(_delta):
	# Keyboard Fallbacks
	if Input.is_action_just_pressed("cast_water"): player.cast_spell(Globals.Element.WATER, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_fire"): player.cast_spell(Globals.Element.FIRE, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_nature"): player.cast_spell(Globals.Element.NATURE, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_light"): player.cast_spell(Globals.Element.LIGHT, get_global_mouse_position())

func _handle_voice_cast(effect_name: String):
	var target = get_global_mouse_position()
	
	match effect_name:
		"fire": 
			player.cast_spell(Globals.Element.FIRE, target)
		"water": 
			player.cast_spell(Globals.Element.WATER, target)
		"nature": 
			player.cast_spell(Globals.Element.NATURE, target)
		"light": 
			player.cast_spell(Globals.Element.LIGHT, target)
		"placeholder_1": print("Placeholder 1 triggered!")
		"placeholder_2": print("Placeholder 2 triggered!")
		"placeholder_3": print("Placeholder 3 triggered!")
		"placeholder_4": print("Placeholder 4 triggered!")
		"placeholder_5": print("Placeholder 5 triggered!")
		_: print("Unknown effect received: ", effect_name)
