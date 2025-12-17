extends CharacterBody2D

@export var player: Node2D

# --------------------
# MOVEMENT & AI
# --------------------
var speed = 40
var move_direction = 1
var gravity = 900
var chase_distance = 500
var attack_distance = 50

# Attack system with randomization (MAX 5 SECONDS TOTAL)
var attack_patterns = []  # Will store different attack patterns
var current_pattern_index = 0
var max_total_attack_time = 5.0  # NEVER exceed 5 seconds total
var is_in_post_attack_idle = false

# Hit reaction
var is_stunned = false
var knockback_force = 50
var hit_freeze_time = 0.1
var is_in_hurt_state = false

# --------------------
# COMBAT
# --------------------
var health = 100
var is_dead = false
var is_attacking = false

# --------------------
# STATE
# --------------------
enum BOSS_STATE {IDLE, RUN, ATTACK, HURT, DEAD, POST_ATTACK_IDLE}
var current_state = BOSS_STATE.IDLE

# --------------------
# NODES
# --------------------
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/AttackCollision
@onready var attack_area = $AttackHitbox  # Area2D node

# --------------------
# READY
# --------------------
func _ready():
	add_to_group("boss")
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			player = get_tree().get_first_node_in_group("Player")
	
	attack_hitbox.disabled = true
	
	collision_layer = 2
	collision_mask = 1  # CRITICAL: Makes boss detect player attacks
	attack_area.collision_mask = 1
	
	if player:
		add_collision_exception_with(player)
	
	if not attack_area.body_entered.is_connected(_on_AttackHitbox_body_entered):
		attack_area.body_entered.connect(_on_AttackHitbox_body_entered)
	
	add_to_group("boss")
	
	# Initialize attack patterns (windup, active, recovery, idle) - TOTAL <= 5.0
	# Format: [windup_time, active_time, recovery_time, idle_time]
	attack_patterns = [
		# Fast attack, short idle (3.5 seconds total)
		[0.2, 0.3, 0.3, 2.7],  # Total: 3.5s
		
		# Medium attack, medium idle (4.0 seconds total)
		[0.3, 0.4, 0.4, 2.9],  # Total: 4.0s
		
		# Slow windup, quick recovery (4.5 seconds total)
		[0.5, 0.2, 0.3, 3.5],  # Total: 4.5s
		
		# Quick double-hit feeling (4.0 seconds total)
		[0.3, 0.2, 0.2, 3.3],  # Total: 4.0s
		
		# Slow powerful attack (5.0 seconds total - MAX)
		[0.6, 0.4, 0.5, 3.5],  # Total: 5.0s
	]
	
	print("BOSS: Loaded ", attack_patterns.size(), " attack patterns (max 5 seconds each)")

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		if animated_sprite.animation != "Death":
			animated_sprite.play("Death")
		return
	
	if is_in_post_attack_idle or is_in_hurt_state:
		move_and_slide()
		play_animation()
		return
	
	if is_stunned:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	if not player:
		move_and_slide()
		play_animation()
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# --------------------
	# AI DECISION
	# --------------------
	if current_state != BOSS_STATE.ATTACK and current_state != BOSS_STATE.HURT and current_state != BOSS_STATE.DEAD and current_state != BOSS_STATE.POST_ATTACK_IDLE:
		if distance_to_player > chase_distance:
			current_state = BOSS_STATE.IDLE
			velocity.x = 0
		elif distance_to_player > attack_distance:
			current_state = BOSS_STATE.RUN
			move_direction = 1 if player.global_position.x > global_position.x else -1
			velocity.x = speed * move_direction
		elif not is_attacking and not is_in_post_attack_idle:
			start_random_attack()  # Changed to random attack

	if player:
		animated_sprite.flip_h = player.global_position.x < global_position.x

	move_and_slide()
	play_animation()

# --------------------
# ANIMATIONS
# --------------------
func play_animation():
	if is_dead:
		animated_sprite.play("Death")
		return
	
	if is_in_hurt_state:
		animated_sprite.play("Hurt")
		return
	
	match current_state:
		BOSS_STATE.IDLE:
			animated_sprite.play("Idle")
		BOSS_STATE.RUN:
			animated_sprite.play("Run")
		BOSS_STATE.ATTACK:
			animated_sprite.play("Attack")
		BOSS_STATE.HURT:
			animated_sprite.play("Hurt")
		BOSS_STATE.POST_ATTACK_IDLE:
			animated_sprite.play("Idle")

# --------------------
# RANDOMIZED ATTACK PATTERNS (MAX 5 SECONDS)
# --------------------
func start_random_attack():
	if is_attacking or current_state == BOSS_STATE.ATTACK or is_in_hurt_state or is_in_post_attack_idle:
		return
	
	# Randomly select an attack pattern
	current_pattern_index = randi() % attack_patterns.size()
	var pattern = attack_patterns[current_pattern_index]
	
	var windup_time = pattern[0]
	var active_time = pattern[1]
	var recovery_time = pattern[2]
	var idle_time = pattern[3]
	
	# Verify total time doesn't exceed 5 seconds
	var total_time = windup_time + active_time + recovery_time + idle_time
	if total_time > max_total_attack_time:
		# Adjust idle time to keep total at 5 seconds
		idle_time = max_total_attack_time - (windup_time + active_time + recovery_time)
		idle_time = max(idle_time, 0.5)  # Minimum 0.5s idle
	
	print("BOSS: Starting RANDOM attack pattern #", current_pattern_index)
	print("BOSS: Pattern times - Windup:", windup_time, "s, Active:", active_time, "s, Recovery:", recovery_time, "s, Idle:", idle_time, "s")
	print("BOSS: Total attack time:", total_time, "s (max 5.0s)")
	
	# Set attack state
	is_attacking = true
	current_state = BOSS_STATE.ATTACK
	velocity.x = 0
	
	# === WINDUP PHASE ===
	modulate = Color.GREEN
	print("BOSS: Windup phase (", windup_time, "s)")
	await get_tree().create_timer(windup_time).timeout
	
	# === ACTIVE HITBOX PHASE ===
	attack_hitbox.disabled = false
	modulate = Color.RED
	print("BOSS: Active hitbox phase (", active_time, "s)")
	await get_tree().create_timer(active_time).timeout
	
	# === RECOVERY PHASE ===
	attack_hitbox.disabled = true
	modulate = Color.YELLOW
	print("BOSS: Recovery phase (", recovery_time, "s)")
	await get_tree().create_timer(recovery_time).timeout
	
	# === POST-ATTACK IDLE PHASE ===
	modulate = Color.WHITE
	is_attacking = false
	current_state = BOSS_STATE.POST_ATTACK_IDLE
	is_in_post_attack_idle = true
	velocity.x = 0
	print("BOSS: Post-attack idle (", idle_time, "s)")
	
	await get_tree().create_timer(idle_time).timeout
	
	# Attack sequence complete
	is_in_post_attack_idle = false
	current_state = BOSS_STATE.RUN
	print("BOSS: Random attack pattern complete!")

# --------------------
# QUICK ATTACK (for reference, not used)
# --------------------
func start_attack():
	# Fallback to a default pattern if needed
	var default_pattern = [0.3, 0.3, 0.4, 4.0]  # Total: 5.0s
	start_specific_attack(default_pattern)

func start_specific_attack(pattern):
	# Same logic as start_random_attack but with specific pattern
	# ... (same code as above but without random selection)
	pass  # Placeholder implementation

# --------------------
# MAIN BODY AREA DETECTION (for receiving damage)
# --------------------
func _on_area_entered(area):
	print("BOSS: Main body touched by area: ", area.name)
	
	# Check if this is the player's attack area
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		print("BOSS: Hit by player's attack!")
		take_damage(20, parent.global_position)
		return
	
	# Alternative check - if area name contains "Attack"
	if "Attack" in area.name:
		print("BOSS: Hit by attack area: ", area.name)
		# Try to find player
		var player = get_tree().get_first_node_in_group("player")
		if player:
			take_damage(20, player.global_position)

# --------------------
# HITBOX SIGNAL (for dealing damage)
# --------------------
func _on_AttackHitbox_body_entered(body):
	print("BOSS: Hit something: ", body.name)
	
	if body.is_in_group("boss"):
		print("BOSS: Skipping - hit another enemy/self")
		return
	
	if body.has_method("take_damage"):
		print("BOSS: SUCCESS - Calling take_damage on player!")
		body.take_damage(10, global_position)

# --------------------
# DAMAGE HANDLING
# --------------------
func take_damage(amount, attacker_position = null):
	print("=== BOSS: take_damage() WAS CALLED! ===")
	print("BOSS take_damage called! is_dead:", is_dead, " is_in_hurt_state:", is_in_hurt_state)
	
	if is_dead:
		print("BOSS: Can't take damage - already dead")
		return

	health -= amount
	print("BOSS took damage: ", amount, " | Health: ", health)

	if health <= 0:
		is_dead = true
		current_state = BOSS_STATE.DEAD
		$CollisionShape2D.disabled = true
		$DeathCollision.disabled = false
		velocity.x = 0
		print("BOSS: DIED!")
	else:
		current_state = BOSS_STATE.HURT
		is_in_hurt_state = true
		is_in_post_attack_idle = false
		apply_hit_reaction(attacker_position)
		
func apply_hit_reaction(attacker_position = null):
	is_attacking = false
	attack_hitbox.disabled = true
	is_in_post_attack_idle = false
	
	is_stunned = true

	var direction = 1
	if attacker_position:
		if global_position.x < attacker_position.x:
			direction = -1
		else:
			direction = 1
	
	velocity.x = direction * knockback_force
	modulate = Color.BLUE
	animated_sprite.pause()

	await get_tree().create_timer(hit_freeze_time).timeout

	animated_sprite.play()
	modulate = Color.WHITE
	is_stunned = false
	
	await get_tree().create_timer(0.5).timeout
	is_in_hurt_state = false
	current_state = BOSS_STATE.RUN
	print("BOSS: Hurt animation finished, back to RUN state")
