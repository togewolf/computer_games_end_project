extends Wizard

@onready var agent_timer = Timer.new()
@onready var speed_slider = $"../SpeedSlider"
@onready var randomness_slider = $"../RandomnessSlider"
@onready var perception_area = $PerceptionArea

var handled_threats : Array[HandledThreat] = []

enum THREAT_RESPONSE { EVADE, PARRY, ACCEPT_DAMAGE }

# Determines how precise our wizard can aim to its target location.
var jitter_radius = 32.0
var wizard_width  = 96.0
var arena_width   = 480.0


var reaction_window = INF # How much the AI predicts spells in advance in seconds.
var min_aggression_time = 0.75 # Minimum time we wait before trying to attack
var max_aggression_time = 3 # Maximum time we wait before trying to attack
var attack_preference = 0.3 # 0 means the wizard prefers speed over targeted missiles

# Parrying and movement is only considering spells that will reach the wizard in the next X seconds

# DEBUGGING
var DEBUG_AI = false

var debug_danger_zones: Array = []
var debug_safe_target: float = INF
var debug_impact_points : Array = []
var debug_considerations : Array[Vector2] = []

@onready var shape = $"./CollisionShape2D"

var evasion_target_x : float = INF;
var next_attack_timer : float = randf_range(min_aggression_time, max_aggression_time)

class IncomingThreatData extends RefCounted:
	var projectile: Projectile
	var distance: float
	var eta: float # How long does it take for it to arrive at our Y axis
	var personal_eta : float # How long does it take for us to arrive at our position - this is based on the dot product

	func _init(p: Projectile, d: float, e: float, pe : float):
		projectile = p
		distance = d
		eta = e
		personal_eta = pe

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
	super()

	wizard_width = shape.shape.radius * 2.0 * scale.x
	print( "Wizard width: ", wizard_width )

	# Setup Agent AI Timer
	add_child(agent_timer)
	self.is_player = false
	agent_timer.timeout.connect(_agent_ai_tick)
	agent_timer.start(speed_slider.value)
	speed_slider.value_changed.connect(func(val): agent_timer.wait_time = val)

func _draw():
	if !DEBUG_AI: return
	
	draw_circle(Vector2.ZERO, wizard_width / 2, Color.AQUA, false, 8)

	# Draw slightly below the wizard's feet so it doesn't overlap the sprite
	var floor_y = 30.0

	for impact in debug_impact_points:
		draw_circle(to_local(Vector2(impact, global_position.y)), 4, Color.CHARTREUSE, true)

	for consideration in debug_considerations:
		draw_circle(to_local(Vector2(consideration.y, global_position.y)), 4, Color.from_rgba8( clamp(round(consideration.x / 3) * 255, 0, 255), 0, 0, 255), true)

	# 1. DRAW THE DANGER ZONES (Red Lines)
	for zone in debug_danger_zones:
		# Convert global X coordinates to local space
		var local_left = to_local(Vector2(zone.min, global_position.y))
		var local_right = to_local(Vector2(zone.max, global_position.y))

		# Set the Y to our floor offset
		local_left.y = floor_y
		local_right.y = floor_y

		# Draw a thick red line (5 pixels wide)
		draw_line(local_left, local_right, Color.RED, 4.0)

	# 2. DRAW THE SAFE TARGET
	if debug_safe_target != INF:
		var local_safe_spot = to_local(Vector2(debug_safe_target, global_position.y))
		local_safe_spot.y = floor_y

		# Draw a green dot where the wizard is currently trying to run
		draw_circle(local_safe_spot, 8.0, Color.PURPLE)
	if (evasion_target_x != INF):
		var local_safe_spot = to_local(Vector2(evasion_target_x, global_position.y))
		local_safe_spot.y = floor_y

		# Draw a green dot where the wizard is currently trying to run
		draw_circle(local_safe_spot, 8.0, Color.WHITE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	advanced_ai(delta)
	queue_redraw()

	if evasion_target_x != INF:
		# 1. Which way do we need to go?
		var distance_to_target = evasion_target_x - global_position.x
		var direction = sign(distance_to_target) # Returns 1 (Right) or -1 (Left)

		# 2. Check if we will arrive THIS frame
		# (Speed * Delta is the exact pixel distance we move this frame)
		if abs(distance_to_target) <= (movespeed * delta):
			# We made it! Snap to the exact spot and stop.
			global_position.x = evasion_target_x
			evasion_target_x = INF # Reset state so we can attack/idle again
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

			# Is threat already handled?
			if handled_threats.any(func(item): return item.projectile == proj):
				continue

			# 1. Fetch vector data from the projectile
			var proj_speed = proj.speed
			var proj_direction = proj.direction

			# 2. Calculate actual distance
			var distance = global_position.distance_to(proj.global_position)

			# 3. Calculate ETA (Time until arrival)
			var velocity = proj_direction * proj_speed
			var relative_direction = (global_position - proj.global_position).normalized()
			var closing_speed = velocity.dot(relative_direction)

			var projectile_radius = 24
			var total_radius = wizard_width / 2 + projectile_radius
			var diff = proj.global_position - global_position
			
			var a = velocity.dot(velocity)
			var b = 2.0 * diff.dot(velocity)
			var c = diff.dot(diff) - (total_radius * total_radius)

			var discr = (b * b) - (4.0 * a * c)
			var personal_eta = INF
			
			if discr >= 0:
				var sqrt_disc = sqrt(discr)
				
				# Calculate entry time (t1) and exit time (t2)
				var t1 = (-b - sqrt_disc) / (2.0 * a)
				var t2 = (-b + sqrt_disc) / (2.0 * a)
			
				if t1 >= 0:
					personal_eta = t1 # Time until it hits our outer edge
				elif t2 >= 0:
					personal_eta = t2 # The projectile is ALREADY inside our radius
		
			var p = proj.global_position
			var d = proj.direction
			var _y= global_position.y

			# We determine the scaling factor of the normalized direction vector to tell when we cross our y axis, which gives us the eta for arriving at our y axis if divided by the speed
			var s = (_y-p.y) / d.y
			var eta = s / proj_speed

			var threat_data = IncomingThreatData.new(
				node,
				distance,
				eta,
				personal_eta,
			)
			threat_list.append(threat_data)

	if threat_list.is_empty():
		return []

	threat_list.sort_custom(func(a, b):
		return a["eta"] < b["eta"]
	)

	return threat_list

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
		var mana_cost     = Globals.get_spell_cost(spell)
		if (mana_cost > current_mana):
			# We simply cannot cast it
			return null

		return Globals.SpellIntent.new(spell, threat.projectile)

func clear_past_threats():
	for i in range(handled_threats.size() - 1, -1, -1):
		var threat = handled_threats[i]

		if not is_instance_valid(threat.projectile):
			handled_threats.remove_at(i)
			continue

		# Maybe it is still existing, but no longer a threat
		var is_moving_up = threat.projectile.direction.y > 0
		var proj_y = threat.projectile.global_position.y

		if is_moving_up and proj_y > global_position.y:
			handled_threats.remove_at(i)
		# Not needed rn, but maybe later we wanna swap positions
		elif not is_moving_up and proj_y < global_position.y:
			handled_threats.remove_at(i)

func get_threats_response():
	# First, determine if our current threats are still valid? - gotta count from behind, so that if we remove an item we aren't losing shit
	clear_past_threats()

	# First, lets see what threats we have:
	var threats = get_detailed_threat_list()

	# We only allow one spell cast per tick here, because otherwise, it gets a lil complicated and he he'd frankly try to spam
	var spell_intent : Globals.SpellIntent = null

	while(spell_intent == null && threats.size() > 0):
		var priority_threat = threats.pop_front()

		# Are we currently trying to evade something already?
		if ( evasion_target_x == INF ):
			# We do not need to parry it maybe
			# Best course of action is usually to avoid first
			var escape_spot : float = INF
			print("We wanna go to ", escape_spot)
			if escape_spot != INF:
				evasion_target_x = escape_spot # We can evade it, let's do that instead
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

func evaluate_combat_state(threats: Array[IncomingThreatData]) -> Dictionary:
	var reaction_window = INF # Only care about spells hitting in the next 1.5s
	var wizard_radius = wizard_width / 2  # Replace with get_physical_width() / 2.0
	var min_x = wizard_radius
	var max_x = get_viewport_rect().size.x - wizard_radius

	var danger_zones = []
	var impact_points = []

	# 1. Map out all Danger Zones
	for threat in threats:
		if threat.personal_eta > reaction_window:
			continue # Ignore threats too far in the future

		var t = (global_position.y - threat.projectile.global_position.y) / threat.projectile.direction.y
		if t <= 0:
			continue
		var impact_x = threat.projectile.global_position.x + (t * threat.projectile.direction.x)


		impact_points.append(impact_x)

		# Get projectile radius safely
		var shape = threat.projectile.get_node_or_null("CollisionShape2D")
		var proj_radius = shape.shape.radius if shape and shape.shape is CircleShape2D else 16.0

		var clearance = proj_radius + wizard_radius

		# We basically create danger zones - intervals on the x axis, that are bound by [Left Bound, Right Bound]
		# And tell where the AI where to not go in order to not be hit by any projectiles
		var zone_left = clamp(impact_x - clearance, min_x, max_x)
		var zone_right = clamp(impact_x + clearance, min_x, max_x)
		danger_zones.append(DangerZone.new(zone_left, zone_right, threat))

	# 2. We merge overlapping danger zones
	# we sort em by their smaller edge
	danger_zones.sort_custom(func(a, b): return a.min < b.min)

	var merged_zones = []
	for zone in danger_zones:
		if merged_zones.is_empty():
			merged_zones.append(zone)
		else:
			var last_idx  = merged_zones.size()-1
			var last_zone = merged_zones[last_idx]
			if zone.min <= last_zone.max: # They overlap or touch!
				last_zone.max = max(last_zone.max, zone.max)
				merged_zones[last_idx] = last_zone
			else:
				merged_zones.append(zone)

	debug_danger_zones = merged_zones
	debug_impact_points = impact_points

	# 3. Check if we are CURRENTLY safe
	var currently_safe = true
	for zone in merged_zones:
		if global_position.x >= zone.min and global_position.x <= zone.max:
			currently_safe = false
			break

	if currently_safe:
		return {"action": "idle"}

	# 4. We are in danger! Find the closest Safe Spot outside the merged zones
	var closest_safe_x = INF
	var shortest_distance = INF

	# Generate potential safe spots (the edges of the danger zones)
	var safe_spots = []
	if merged_zones[0].x > min_x: safe_spots.append(merged_zones[0].x - 1.0) # Left of the first zone
	if merged_zones[-1].y < max_x: safe_spots.append(merged_zones[-1].y + 1.0) # Right of the last zone

	for i in range(merged_zones.size() - 1):
		# The gap between two merged zones
		var gap_center = (merged_zones[i].y + merged_zones[i+1].x) / 2.0
		safe_spots.append(gap_center)

	# Find the closest one
	for spot in safe_spots:
		var dist = abs(spot - global_position.x)
		if dist < shortest_distance:
			shortest_distance = dist
			closest_safe_x = spot

	# 5. Can we reach it in time?
	if closest_safe_x != INF:
		var time_to_reach = shortest_distance / movespeed

		# Does the closest threat hit us before we get there?
		if time_to_reach < threats[0].eta:
			debug_safe_target = closest_safe_x # SAVE FOR DEBUG DRAWING
			return {"action": "dodge", "target_x": closest_safe_x}

	# 6. TRAPPED! We cannot reach a safe spot in time.
	# We MUST parry the most immediate threat.
	return {"action": "parry", "parry_target": threats[0].projectile}

class DangerZone extends RefCounted:
	var min : float
	var max : float
	var threat : IncomingThreatData

	func _init(x, y, _threat):
		self.min = x
		self.max = y
		self.threat = _threat


func evaluate_combat_state_adv(threats : Array[IncomingThreatData]) -> Dictionary:
	var reaction_window = INF # Only care about spells hitting in the next 1.5s
	var wizard_radius = wizard_width / 2  # Replace with get_physical_width() / 2.0
	var min_x = wizard_radius
	var max_x = arena_width - wizard_radius
	var padding = 4

	var impact_points = []

	var danger_zones: Array[DangerZone] = []

	# 1. Map out all Danger Zones
	for threat in threats:
		if threat.personal_eta > reaction_window:
			continue # Ignore threats too far in the future

		var t = (global_position.y - threat.projectile.global_position.y) / threat.projectile.direction.y
		if t <= 0:
			continue
			
		var impact_x = threat.projectile.global_position.x + (t * threat.projectile.direction.x)
		
		impact_points.append(impact_x)
		
		var low_y  = global_position.y - wizard_radius
		var high_y = global_position.y - wizard_radius

		var t0 = (low_y  - threat.projectile.global_position.y) / threat.projectile.direction.y
		var t1 = (high_y - threat.projectile.global_position.y) / threat.projectile.direction.y

		var i0 = threat.projectile.global_position.x + (t0 * threat.projectile.direction.x)
		var i1 = threat.projectile.global_position.x + (t1 * threat.projectile.direction.x)
		
		var left_impact  = min(i0,i1, impact_x)
		var right_impact = max(i0,i1, impact_x)

		# Get projectile radius safely
		var shape = threat.projectile.get_node_or_null("CollisionShape2D")
		var proj_radius = shape.shape.radius if shape and shape.shape is CircleShape2D else 16.0

		var clearance = proj_radius + wizard_radius + padding

		# We basically create danger zones - intervals on the x axis, that are bound by [Left Bound, Right Bound]
		# And tell where the AI where to not go in order to not be hit by any projectiles
		var zone_left = clamp(left_impact - clearance, min_x, max_x)
		var zone_right = clamp(right_impact + clearance, min_x, max_x)
		danger_zones.append( DangerZone.new( zone_left, zone_right, threat ) )

	debug_danger_zones = danger_zones
	debug_impact_points = impact_points
	if danger_zones.is_empty():
		return {"action": "idle"}

	# collect unique X coordinates that define boundaries, so that we can rank them on their risk
	var boundaries: Array[float] = [min_x, max_x]
	for zone in danger_zones:
		boundaries.append(zone.min)
		boundaries.append(zone.max)
	boundaries.sort()

	# We clean duplicates
	var unique_boundaries: Array[float] = []
	for b in boundaries:
		if unique_boundaries.is_empty() or abs(unique_boundaries.back() - b) > 0.01:
			unique_boundaries.append(b)

	# 4. Analyze our current position's danger score
	var current_threats = []
	for zone in danger_zones:
		if global_position.x >= zone.min and global_position.x <= zone.max:
			current_threats.push_back(zone.threat)

	var local_threats = current_threats
	var local_threats_count = local_threats.size()
	
	# If we are not being hit, we simply omit the decision tree. We simply stay where we are
	if local_threats_count == 0:
		return {"action": "idle"} # We are perfectly safe standing still!


	# We now start ranking every sector between boundaries
	var best_sector_center: float = global_position.x
	var lowest_bullet_count: int = 999999
	var shortest_distance_to_best: float = INF
	var still_lingering_threats = current_threats

	var considerations : Array[Vector2] = []

	for i in range(unique_boundaries.size() - 1):
		var sector_center = unique_boundaries[i]

		# Unlike the previous AI version I made, we are actually keeping the intervals here
		# The idea is that knowing the overlapping intervals still we actually can determine
		# a ranking for every of these points and determine by how many spells we would be hit
		# if we picked that one spot

		# We want the sector with the absolute lowest damage.
		# If there's a tie, we pick the one closest to our current position.
		var dist_to_sector = abs(sector_center - global_position.x)

		# Technically we call already discard any sectors we cannot reach anyway here
		var time_to_reach = dist_to_sector / movespeed
		# Note that, because the personal ETA is based on our position it does not tell us when the current decision is invalid.
		# After all, this decision changes whenever a projectil is no longer a threat, thus we discard any point outside
		if (time_to_reach > threats[0].eta):
			continue

		current_threats.clear()
		for zone in danger_zones:
			if sector_center > zone.min and sector_center < zone.max:
				current_threats.push_back(zone.threat)
				
		considerations.push_back(Vector2(current_threats.size(), sector_center))

		if dist_to_sector <= shortest_distance_to_best and current_threats.size() <= lowest_bullet_count:
			best_sector_center = sector_center
			shortest_distance_to_best = dist_to_sector
			lowest_bullet_count = current_threats.size()
			still_lingering_threats = current_threats

	debug_considerations = considerations
	# Now we sort by personal ETA
	
	# If there was no sector we can even get to to get less damage, we simply parry
	if shortest_distance_to_best == INF:
		debug_safe_target = INF
		local_threats.sort_custom(func(a,b): return a.distance < b.distance)
				
		return {"action": "parry", "parry_target": local_threats[0]}

	# If a strictly better/safer spot exists we can get to we run?
	if lowest_bullet_count < local_threats_count:
		# We can make it to a safer zone before the first bullet impacts
		debug_safe_target = best_sector_center
		still_lingering_threats.sort_custom(func(a,b): return abs(a.eta) < abs(b.eta))
		return {"action": "dodge", "target_x": best_sector_center, "present_threats": still_lingering_threats}

	# Else, stand ground and parry the most immediate threat.
	debug_safe_target = INF
	local_threats.sort_custom(func(a,b): return a.distance < b.distance)
	return {"action": "parry", "parry_target": local_threats[0]}

#endregion

func _agent_ai_tick():
	return
	# Defense first! Do we need to repsond to incoming threats?
	#var spell_intent = get_threats_response()

	#if(spell_intent != null):
	#	agent_spell_cast(spell_intent)

func decide_on_attack(threats_count):
	if next_attack_timer > 0: return
	next_attack_timer = randf_range(min_aggression_time, max_aggression_time)
	
	var free_balance = current_mana - threats_count * Globals.BASE_MULTIPLIER
	# Let's see what we can do
	var target = self.opponent
	# Choose random element
	var element : Globals.Element = randi_range(0,3)
	var desired_speed : Globals.ProjectileSpeed = randi_range(0,2)
	var desired_mode  : Globals.ProjectileMode = randi_range(0,1)
	# Degrade our attack until we can afford it
	
	var fail_count  = 0
	var max_fails   = 5
	
	var intent = Globals.SpellDescriptor.new(element, desired_speed, desired_mode)
	
	while (free_balance < Globals.get_spell_cost(intent) && fail_count < max_fails):
		var degrade_speed = randf() < attack_preference
		if degrade_speed:
			desired_speed = clampi(desired_speed, 0, 2)
		else:
			desired_mode  = clampi(desired_mode, 0, 1)
		
		fail_count += 1
		intent = Globals.SpellDescriptor.new(element, desired_speed, desired_mode)
	
	
	# Can we cast this now?
	if free_balance >= Globals.get_spell_cost(intent):
		return Globals.SpellIntent.new(intent, target)
	else:
		return null

func advanced_ai(delta : float):
	next_attack_timer -= delta
	clear_past_threats()
	
	var threats  = get_detailed_threat_list()
	var decision = evaluate_combat_state_adv(threats)
	var intent   = null
	var attack   = true # We always have a desire to attack >:)

	match decision["action"]:
		"dodge":
			# We set our escape to the move target
			evasion_target_x = decision["target_x"]
			var existing_threats = decision["present_threats"]
			if (existing_threats.size() > 0):
				var priority_threat = existing_threats[0]
				# Save our mana first for a defense!
				attack = false
				if (priority_threat.eta > 0 && priority_threat.distance < 3 * wizard_width ): # It did not cross the y axis yet but it is getting very close!
					intent = decide_on_parry_spell(priority_threat)
					handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.PARRY, 1, INF))
		"parry":
			# Primary goal is to parry
			evasion_target_x = INF
			var priority_threat = decision["parry_target"]
			attack = false
			if (priority_threat.eta > 0 && priority_threat.distance < 3 * wizard_width): # It did not cross the y axis yet but it is getting very close!
					intent = decide_on_parry_spell(priority_threat)
					handled_threats.push_back(HandledThreat.new(priority_threat.projectile, THREAT_RESPONSE.PARRY, 1, INF))
		"idle":
			# We are safe for now,
			evasion_target_x = arena_width / 2 # We try to go back to the centre, to avoid being cornered
		
	if attack:
		intent = decide_on_attack(threats.size())
	if (intent != null):
		agent_spell_cast(intent)
