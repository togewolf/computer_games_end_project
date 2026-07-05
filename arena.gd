extends Node2D

@onready var player = $WizardPlayer
@onready var agent = $WizardAgent  

@onready var player_hp_bar = $PlayerHP
@onready var agent_hp_bar = $AgentHP
@onready var player_mana_bar = $PlayerMana
@onready var agent_mana_bar = $AgentMana

@onready var voice_manager = $VoiceManager 

func _ready():
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.max_health
	player_mana_bar.max_value = player.max_mana
	player_mana_bar.value = player.max_mana
	
	player.health_changed.connect(func(hp): player_hp_bar.value = hp)
	player.mana_changed.connect(func(mana): player_mana_bar.value = mana)
	
	player.opponent = agent;
	
	agent_hp_bar.max_value = agent.max_health
	agent_hp_bar.value = agent.max_health
	agent_mana_bar.max_value = agent.max_mana
	agent_mana_bar.value = agent.max_mana
	
	agent.health_changed.connect(func(hp): agent_hp_bar.value = hp)
	agent.mana_changed.connect(func(mana): agent_mana_bar.value = mana)
	agent.opponent = player;

	# End the match when either wizard's health reaches 0
	player.health_changed.connect(_check_player_defeat)
	agent.health_changed.connect(_check_agent_defeat)

	voice_manager.voice_command_received.connect(_handle_voice_cast)

func _process(_delta):
	# Keyboard Fallbacks
	if Input.is_action_just_pressed("cast_water"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.WATER, 
			Globals.ProjectileSpeed.NORMAL, 
			Globals.ProjectileMode.PROJECTILE), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_fire"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.FIRE, 
			Globals.ProjectileSpeed.NORMAL, 
			Globals.ProjectileMode.PROJECTILE), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_nature"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.NATURE, 
			Globals.ProjectileSpeed.NORMAL, 
			Globals.ProjectileMode.PROJECTILE), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_light"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.LIGHT, 
			Globals.ProjectileSpeed.NORMAL, 
			Globals.ProjectileMode.PROJECTILE), 
		get_global_mouse_position())

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

func _check_player_defeat(hp):
	if hp <= 0:
		$GameOverLayer.show_result(false)

func _check_agent_defeat(hp):
	if hp <= 0:
		$GameOverLayer.show_result(true)