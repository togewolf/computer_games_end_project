extends Node2D

@onready var player = $WizardPlayer
@onready var agent = $WizardAgent  

@onready var player_hp_bar = $PlayerHP
@onready var agent_hp_bar = $AgentHP

func _ready():
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.max_health
	player.health_changed.connect(func(hp): player_hp_bar.value = hp)
	player.opponent = agent;
	
	agent_hp_bar.max_value = agent.max_health
	agent_hp_bar.value = agent.max_health
	agent.health_changed.connect(func(hp): agent_hp_bar.value = hp)
	agent.opponent = player;

func _process(_delta):
	# Placeholder Input Detection (Replace with ML Keyword later)
	if Input.is_action_just_pressed("cast_water"): player.cast_spell(Globals.Element.WATER, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_fire"): player.cast_spell(Globals.Element.FIRE, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_nature"): player.cast_spell(Globals.Element.NATURE, get_global_mouse_position())
	elif Input.is_action_just_pressed("cast_light"): player.cast_spell(Globals.Element.LIGHT, get_global_mouse_position())
	
