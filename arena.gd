extends Node2D

@onready var player = $WizardPlayer
@onready var agent = $WizardAgent  

@onready var player_hp_bar = $PlayerHP
@onready var agent_hp_bar = $AgentHP
@onready var player_mana_bar = $PlayerMana
@onready var agent_mana_bar = $AgentMana

@onready var voice_manager = $VoiceManager 

var current_speed: Globals.ProjectileSpeed = Globals.ProjectileSpeed.NORMAL
var current_mode: Globals.ProjectileMode = Globals.ProjectileMode.PROJECTILE

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
	if Input.is_action_just_pressed("toggle_debug"):
		agent.DEBUG_AI = not agent.DEBUG_AI
		
	if Input.is_action_just_pressed("speed_normal"):
		current_speed = Globals.ProjectileSpeed.NORMAL
	elif Input.is_action_just_pressed("speed__faster"):
		current_speed = Globals.ProjectileSpeed.FASTER
	elif Input.is_action_just_pressed("speed_fastest"):
		current_speed = Globals.ProjectileSpeed.FASTEST
		
	if Input.is_action_just_pressed("normal_mode"):
		current_mode = Globals.ProjectileMode.PROJECTILE
	elif Input.is_action_just_pressed("targeted_mode"):
		current_mode = Globals.ProjectileMode.TARGETED
		
	# Keyboard Fallbacks
	if Input.is_action_just_pressed("cast_water"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.WATER, 
			current_speed, 
			current_mode), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_fire"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.FIRE, 
			current_speed, 
			current_mode), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_nature"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.NATURE, 
			current_speed, 
			current_mode), 
		get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_light"): player.cast_spell(
		Globals.SpellDescriptor.new(
			Globals.Element.LIGHT, 
			current_speed, 
			current_mode), 
		get_global_mouse_position())

func _handle_voice_cast(effect_name: String):
	var target = get_global_mouse_position()
	
	match effect_name:
		"fire": 
			player.cast_spell(
			Globals.SpellDescriptor.new(
			Globals.Element.FIRE, 
			current_speed, 
			current_mode), 
			target)
		"water": 
			player.cast_spell(
			Globals.SpellDescriptor.new(
			Globals.Element.WATER, 
			current_speed, 
			current_mode), 
			target)
		"nature": 
			player.cast_spell(
			Globals.SpellDescriptor.new(
			Globals.Element.NATURE, 
			current_speed, 
			current_mode), 
			target)
		"light": 
			player.cast_spell(
			Globals.SpellDescriptor.new(
			Globals.Element.LIGHT, 
			current_speed, 
			current_mode), 
			target)
		"projectile": 
			current_mode = Globals.ProjectileMode.PROJECTILE
			print("projectile mode triggered!")
		"target": 
			current_mode = Globals.ProjectileMode.TARGETED
			print("target mode triggered!")
		"slow": 
			current_speed = Globals.ProjectileSpeed.NORMAL
			print("slow triggered!")
		"fast": 
			current_speed = Globals.ProjectileSpeed.FASTER
			print("fast triggered!")
		"fastest": 
			current_speed = Globals.ProjectileSpeed.FASTEST
			print("fasteset triggered!")
		_: print("Unknown effect received: ", effect_name)

func _check_player_defeat(hp):
	if hp <= 0:
		$GameOverLayer.show_result(false)

func _check_agent_defeat(hp):
	if hp <= 0:
		$GameOverLayer.show_result(true)
