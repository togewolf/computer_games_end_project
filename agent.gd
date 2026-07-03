extends Wizard

@onready var agent_timer = Timer.new()
@onready var speed_slider = $"../SpeedSlider"
@onready var randomness_slider = $"../RandomnessSlider"
@onready var perception_area = $PerceptionArea

var handled_threats : Array[HandledThreat] = []

enum THREAT_RESPONSE { EVADE, PARRY, ACCEPT_DAMAGE }

# Determines how precise our wizard can aim to its target location.
var jitter_radius = 32.0
var wizard_width;
var arena_width   = 480.0

@onready var shape = $"./CollisionShape2D"

var evasion_spot : float = INF;

class IncomingThreatData extends RefCounted:
	var projectile: Projectile
	var distance: float
	var eta: float

	func _init(p: Projectile, d: float, e: float):
		projectile = p
		distance = d
		eta = e

class HandledThreat extends RefCounted:
	var projectile : Projectile
	var response   : THREAT_RESPONSE
	var priority   : int
	var safe_spot_x: float

	func _init(p: Projectile, r : THREAT_RESPONSE, prio: int, spot : float):
		self.projectile = p
		self.response = r
		self.priority = prio
		self.safe_spot_x = spot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	wizard_width = shape.shape.radius * 2.0
	
	# Setup Agent AI Timer
	add_child(agent_timer)
	self.is_player = false
	agent_timer.timeout.connect(_agent_ai_tick)
	agent_timer.start(speed_slider.value)
	speed_slider.value_changed.connect(func(val): agent_timer.wait_time = val)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if evasion_spot != INF:
		# 1. Which way do we need to go?
		var distance_to_target = evasion_spot - global_position.x
		var direction = sign(distance_to_target) # Returns 1 (Right) or -1 (Left)
		
		# 2. Check if we will arrive THIS frame
		# (Speed * Delta is the exact pixel distance we move this frame)
		if abs(distance_to_target) <= (movespeed * delta):
			# We made it! Snap to the exact spot and stop.
			global_position.x = evasion_spot
			evasion_spot = INF # Reset state so we can attack/idle again
		else:
			# Keep running toward the target
			position.x += direction * movespeed * delta
			
		return # Skip the rest of the AI logic while running for our lives
	
	pass

func agent_spell_cast(intent : Globals.SpellIntent):
	self.cast_spell(intent.spell, aim_at_target(intent.target))

#region Agent logic

func get_detailed_threat_list() -> Array[IncomingThreatData]:
	var overlapping_nodes = perception_area.get_overlapping_areas() # Or get_overlapping_bodies()
	var threat_list : Array[IncomingThreatData] = []

	for node in overlapping_nodes:
		if node.is_in_group("Projectiles"):
			var proj := node as Projectile
			if !proj.is_player_owned: continue

			print("We found threat: ", proj)
			print("current threats: ")
			for i in handled_threats:
				print("threats: ", i)

			# Is threat already handled?
			if handled_threats.any(func(item): return item.projectile == proj):
				continue

			# 1. Fetch vector data from the projectile
			var proj_speed = proj.speed
			var proj_direction = proj.direction

			# 2. Calculate actual distance
			var distance = global_position.distance_to(node.global_position)

			# 3. Calculate ETA (Time until arrival)
			var velocity = proj_direction * proj_speed
			var relative_direction = (global_position - node.global_position).normalized()
			var closing_speed = velocity.dot(relative_direction)

			var eta = INF # Default to infinity if it's flying away
			if closing_speed > 0:
				eta = distance / closing_speed

			var threat_data = IncomingThreatData.new(
				node,
				distance,
				eta
			)
			threat_list.append(threat_data)

	if threat_list.is_empty():
		return []

	threat_list.sort_custom(func(a, b):
		return a["eta"] < b["eta"]
	)

	return threat_list

func calculate_escape_spot(threat: IncomingThreatData) -> float:
	# If ETA is infinite, it's flying away from us. No need to move.
	if threat.eta == INF:
		return INF

	var proj = threat.projectile
	
	var min_x = wizard_width / 2
	var max_x = arena_width - wizard_width / 2

	# WHERE will the projectile be on the X-axis at the moment of impact
	var projectile_speed_x = proj.direction.x * proj.speed
	var impact_x = proj.global_position.x + (projectile_speed_x * threat.eta)

	# get projectile's bounding radius
	var proj_collision = proj.get_node("CollisionShape2D")
	var safety_margin = 16.0

	if proj_collision and proj_collision.shape is CircleShape2D:
		safety_margin = proj_collision.shape.radius

	var wizard_margin = wizard_width # adjust based on your wizard's sprite width
	var total_clearance_needed = safety_margin + wizard_margin

	# calculate required distance to move Left vs Right to clear the impact zone
	var target_left_x = impact_x - total_clearance_needed
	var target_right_x = impact_x + total_clearance_needed
	
	print("arena w", arena_width)
	
	print("esc")
	print(target_left_x)
	print(target_right_x)

	var distance_to_escape_left = abs(target_left_x - global_position.x)
	var distance_to_escape_right = abs(target_right_x - global_position.x)

	# Time required for the wizard to reach those safety points
	var time_to_escape_left = distance_to_escape_left / movespeed
	var time_to_escape_right = distance_to_escape_right / movespeed

	if (target_left_x < min_x):
		time_to_escape_left = INF
	if (target_right_x > max_x ):
		time_to_escape_right = INF

	print("it would take ", time_to_escape_left, "s and ", time_to_escape_right, "s")

	# evaluate choices based on our IncomingThreatData's exact ETA
	var can_escape_left = time_to_escape_left < threat.eta
	var can_escape_right = time_to_escape_right < threat.eta

	# pick the safest, fastest route
	if can_escape_left and can_escape_right:
		# Return the coordinate that requires the shortest run
		return target_left_x if distance_to_escape_left < distance_to_escape_right else target_right_x
	elif can_escape_left:
		return target_left_x
	elif can_escape_right:
		return target_right_x

	# If neither time is fast enough, return INF to signal we are trapped!
	return INF

func aim_at_target(target : Node2D) -> Vector2:
	# Determine where we want to aim
	var target_location = target.global_position

	# Spell weaving
	var jitter_angle    = randf() * 360
	var jitter_distance = randf() * jitter_radius
	var aim_position    = target_location + Vector2.from_angle(jitter_angle) * jitter_distance

	return aim_position

func decide_on_parry_spell(threat : IncomingThreatData) -> Globals.SpellIntent:
		# No other way than to actually parry it!
		var spell_element = Globals.get_best_response(threat.projectile.element)
		# Parries do not need speed
		var spell_speed   = Globals.ProjectileSpeed.NORMAL
		var spell_mode    = Globals.ProjectileMode.PROJECTILE

		var spell = Globals.SpellDescriptor.new(spell_element, spell_speed, spell_mode);
		# TODO: Calculate the mana to HP cost ratio and whether we can even parry it
		var mana_cost     = Globals.get_spell_cost(spell)
		if (mana_cost > current_mana):
			# We simply cannot cast it
			return null

		return Globals.SpellIntent.new(spell, threat.projectile)

func get_threats_response():
	# First, determine if our current threats are still valid? - gotta count from behind, so that if we remove an item we aren't losing shit
	for i in range(handled_threats.size() - 1, -1, -1):
		var threat = handled_threats[i]

		if not is_instance_valid(threat.projectile):
			print("invalid ")
			handled_threats.remove_at(i)
			continue

		# Maybe it is still existing, but no longer a threat
		var is_moving_up = threat.projectile.direction.y > 0
		var proj_y = threat.projectile.global_position.y

		if is_moving_up and proj_y > global_position.y:
			print("decide 1")
			handled_threats.remove_at(i)
		# Not needed rn, but maybe later we wanna swap positions
		elif not is_moving_up and proj_y < global_position.y:
			print("decide 2")
			handled_threats.remove_at(i)

	# First, lets see what threats we have:
	var threats = get_detailed_threat_list()

	# We only allow one spell cast per tick here, because otherwise, it gets a lil complicated and he he'd frankly try to spam
	var spell_intent : Globals.SpellIntent = null

	while(spell_intent == null && threats.size() > 0):
		var priority_threat = threats.pop_front()

		# Are we currently trying to evade something already?
		if ( evasion_spot == INF ):
			# We do not need to parry it maybe
			# Best course of action is usually to avoid first
			var escape_spot : float = calculate_escape_spot(
				priority_threat
			)
			print("We wanna go to ", escape_spot)
			if escape_spot != INF:
				evasion_spot = escape_spot # We can evade it, let's do that instead
				handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.EVADE, 1, escape_spot))
			else:
				spell_intent = decide_on_parry_spell(priority_threat)
				if (spell_intent != null):
					handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.PARRY, 1, escape_spot))
				else:
					handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.ACCEPT_DAMAGE, 1, escape_spot))
		else:
			spell_intent = decide_on_parry_spell(priority_threat)
			if (spell_intent != null):
				handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.PARRY, 1, INF))
			else:
				handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.ACCEPT_DAMAGE, 1, INF))

	return spell_intent

#endregion


func _agent_ai_tick():
	# Defense first! Do we need to repsond to incoming threats?
	var spell_intent = get_threats_response()

	if(spell_intent != null):
		agent_spell_cast(spell_intent)
