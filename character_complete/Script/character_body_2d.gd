extends CharacterBody2D

# ===== NODE REFERENCES =====
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var attack_collision = $AttackArea/CollisionShape2D

# ===== MOVEMENT CONSTANTS =====
const SPEED = 200
const JUMP_POWER = -350.0
var gravity = 900

# ===== COMBAT & STATE VARIABLES =====
var is_attacking = false
var weapon_equip: bool
var is_hit = false
var knockback_force = 50
var health = 100
var can_take_damage = true
var is_dead = false
var spawn_position: Vector2
var is_invincible = false  # NEW: For respawn invincibility
var respawn_invincibility_time = 2.0  # NEW: How long invincibility lasts after respawn

# ===== INITIALIZATION =====
func _ready():
	weapon_equip = false
	attack_collision.disabled = true
	
	# Set collision layers
	collision_layer = 1  # Player on layer 1
	attack_area.collision_mask = 2  # Attack hits only boss (layer 2)
	
	# CRITICAL FIX #1: CONNECT THE SIGNAL
	if not attack_area.area_entered.is_connected(_on_attack_area_entered):
		attack_area.area_entered.connect(_on_attack_area_entered)
		print("PLAYER: Attack signal connected")
	
	# Store initial position as respawn point
	spawn_position = global_position
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)  # HUGE hitbox
	attack_collision.shape = shape
	
	# Add player to group
	add_to_group("player")

# ===== PHYSICS PROCESS =====
func _physics_process(delta):
	if is_dead:  # If dead, don't process physics
		return
	
	if is_hit:  # If being knocked back, just apply movement
		move_and_slide()
		return
	
	# Apply gravity ALWAYS when not on floor (fixed floating issue)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Handle jump input
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_POWER

	# Handle attack input
	if Input.is_action_just_pressed("mouse_attack") and not is_attacking:
		attack()

	# Handle horizontal movement
	var direction = Input.get_axis("left", "right")
	if not is_attacking and not is_hit:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = 0

	# Apply movement
	move_and_slide()
	
	# Update animation
	if not is_hit:
		handle_movement_animation(direction)

# ===== ANIMATION HANDLING =====
func handle_movement_animation(dir):
	if is_attacking or is_hit:
		return

	if not weapon_equip:
		if is_on_floor():
			if velocity.x == 0:
				animated_sprite.play("Idle")
			else:
				animated_sprite.play("run")
				toggle_flip_sprite(dir)
		else:
			animated_sprite.play("Fall")

func toggle_flip_sprite(dir):
	if dir > 0:
		animated_sprite.flip_h = false
	elif dir < 0:
		animated_sprite.flip_h = true

# ===== ATTACK SYSTEM =====
func attack():
	if is_attacking or is_dead:  # Can't attack while dead
		return

	print("PLAYER: Attacking!")
	is_attacking = true
	animated_sprite.play("Single Attack")
	
	# Wait for windup/anticipation frames
	await get_tree().create_timer(0.15).timeout
	
	# Enable hitbox at the moment of impact
	attack_collision.disabled = false
	modulate = Color.YELLOW
	print("PLAYER: Attack hitbox ENABLED")
	
	# CRITICAL FIX #2: MAKE SURE AREA IS MONITORING
	attack_area.monitoring = true
	
	# Keep hitbox active for attack duration
	await get_tree().create_timer(0.15).timeout
	
	# Disable hitbox after attack frames
	attack_collision.disabled = true
	modulate = Color.WHITE
	print("PLAYER: Attack hitbox DISABLED")
	
	# CRITICAL FIX #3: WAIT A BIT BEFORE DISABLING MONITORING
	await get_tree().create_timer(0.05).timeout
	attack_area.monitoring = false
	
	# Wait for recovery frames of animation
	await get_tree().create_timer(0.1).timeout
	
	# Reset attack state
	is_attacking = false

func _on_attack_area_entered(area):
	print("=== PLAYER ATTACK HIT SOMETHING ===")
	print("Area name: ", area.name)
	print("Area parent: ", area.get_parent().name)
	
	var parent = area.get_parent()
	if parent == self:
		print("Ignoring self-hit")
		return
	
	# CRITICAL FIX: Check BOSS group
	if parent.is_in_group("boss"):
		print("PLAYER: Found boss via 'boss' group!")
		if parent.has_method("take_damage"):
			print("PLAYER: SUCCESS - Damaging BOSS!")
			parent.take_damage(20, global_position)
		return
	
	# Fallback: check for take_damage method
	if parent.has_method("take_damage"):
		print("PLAYER: SUCCESS - Damaging via area!")
		parent.take_damage(20, global_position)
	else:
		print("PLAYER: Parent doesn't have take_damage method")

# ===== ANIMATION FINISHED EVENT =====
func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "Death":
		print("PLAYER: Death animation finished")
	# Don't do anything for other animations - let attack() function handle timing

# ===== DAMAGE & HEALTH SYSTEM =====
func take_damage(damage, attacker_position = null):
	# NEW: Check invincibility
	if is_hit or not can_take_damage or is_dead or is_invincible:
		print("PLAYER: Invincible - no damage taken")
		return
	
	can_take_damage = false
	print("PLAYER: Taking ", damage, " damage!")
	health -= damage
	print("PLAYER Health: ", health, "/10")
	
	if health <= 0:
		die()
	else:
		apply_knockback(attacker_position)
	
	await get_tree().create_timer(0.5).timeout
	can_take_damage = true

# ===== DEATH SYSTEM =====
func die():
	print("PLAYER: DIED!")
	is_dead = true
	is_attacking = false  # Reset attacking state
	
	# Disable all collisions
	$CollisionShape2D.disabled = true
	attack_collision.disabled = true
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Play death animation
	animated_sprite.play("Death")
	modulate = Color.DARK_RED
	
	# Wait for death animation
	await animated_sprite.animation_finished
	print("PLAYER: Death animation complete")
	
	# Wait before respawning
	await get_tree().create_timer(1.0).timeout
	
	# Respawn
	respawn()

# ===== RESPAWN SYSTEM (UPDATED WITH INVINCIBILITY) =====
func respawn():
	print("PLAYER: Respawning...")
	
	# Reset all state variables
	is_dead = false
	is_hit = false
	is_attacking = false  # Ensure attack state is reset
	health = 10
	can_take_damage = true
	
	# Re-enable collisions
	$CollisionShape2D.disabled = false
	attack_collision.disabled = true
	
	# Reset visual appearance
	modulate = Color.WHITE
	
	# Move back to spawn position and reset velocity
	global_position = spawn_position
	velocity = Vector2.ZERO  # IMPORTANT: Reset velocity to prevent floating
	
	# Play idle animation
	animated_sprite.play("Idle")
	
	# NEW: Activate invincibility frames
	activate_respawn_invincibility()
	
	print("PLAYER: Respawn complete! Health: ", health)

# ===== NEW: INVINCIBILITY SYSTEM =====
func activate_respawn_invincibility():
	is_invincible = true
	print("PLAYER: Invincibility ACTIVATED for ", respawn_invincibility_time, " seconds")
	
	# Visual feedback: Blinking effect
	var blink_timer = 0.0
	while blink_timer < respawn_invincibility_time:
		# Blink between normal and semi-transparent
		if modulate.a == 1.0:
			modulate = Color(1, 1, 1, 0.3)  # Semi-transparent
		else:
			modulate = Color.WHITE  # Normal
		
		await get_tree().create_timer(0.1).timeout  # Blink every 0.1 seconds
		blink_timer += 0.1
	
	# End invincibility
	is_invincible = false
	modulate = Color.WHITE  # Ensure full opacity
	print("PLAYER: Invincibility ENDED")

# ===== KNOCKBACK SYSTEM =====
func apply_knockback(attacker_position = null):
	print("PLAYER: Applying knockback")
	is_hit = true
	is_attacking = false  # Cancel any ongoing attack
	
	var direction = 1
	if attacker_position:
		if global_position.x < attacker_position.x:
			direction = -1
		else:
			direction = 1
	
	velocity.y = -75
	velocity.x = direction * knockback_force
	
	modulate = Color.RED
	print("PLAYER: Knockback direction: ", direction, " Velocity: ", velocity)
	
	move_and_slide()
	
	# Flash effect
	for i in range(3):
		modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
	
	modulate = Color.WHITE
	is_hit = false
	print("PLAYER: Knockback finished")
