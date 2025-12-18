extends CharacterBody2D

class_name Player

signal healthChanged

# ===== NODE REFERENCES =====
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var attack_collision = $AttackArea/CollisionShape2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
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
var is_invincible = false
var respawn_invincibility_time = 2.0
var currentHealth = health

# ===== INITIALIZATION =====
func _ready():
	weapon_equip = false
	attack_collision.disabled = true

	collision_layer = 1
	attack_area.collision_mask = 2

	# NEW: stop pushing against boss bodies
	for boss in get_tree().get_nodes_in_group("boss"):
		add_collision_exception_with(boss as Node)
		
	# Connect signal
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		print("PLAYER: Attack signal connected")
	
	# Store initial position as respawn point
	spawn_position = global_position
	
	add_to_group("player")

# ===== PHYSICS PROCESS =====
func _physics_process(delta):
	if is_dead:
		return
	
	if is_hit:
		move_and_slide()
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_POWER

	# Attack
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_attacking:
		attack()

	# Horizontal movement
	var direction = Input.get_axis("left", "right")
	if not is_attacking and not is_hit:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = 0

	move_and_slide()
	
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
				toggle_flip_sprite(dir)   # calls flip each frame while running
		else:
			animated_sprite.play("Fall")

func toggle_flip_sprite(dir):
	# Flip sprite
	if dir > 0:
		animated_sprite.flip_h = false
	elif dir < 0:
		animated_sprite.flip_h = true

	# HUGE offset so you can’t miss it
	var offset := 16

	var local_pos: Vector2 = attack_collision.position
	if animated_sprite.flip_h:
		local_pos.x = -offset
	else:
		local_pos.x = offset
	attack_collision.position = local_pos

	print("FLIP: flip_h =", animated_sprite.flip_h, " attack_collision =", attack_collision.position)


# ===== ATTACK SYSTEM =====
func attack():
	if is_attacking or is_dead:
		return

	print("PLAYER: Attacking!")
	is_attacking = true
	animated_sprite.play("Single Attack")
	
	await get_tree().create_timer(0.15).timeout   # windup
	
	attack_collision.disabled = false
	modulate = Color.YELLOW
	print("PLAYER: Attack hitbox ENABLED")
	attack_area.monitoring = true
	
	await get_tree().create_timer(0.15).timeout   # active
	
	attack_collision.disabled = true
	modulate = Color.WHITE
	print("PLAYER: Attack hitbox DISABLED")
	
	await get_tree().create_timer(0.05).timeout
	attack_area.monitoring = false
	
	await get_tree().create_timer(0.1).timeout    # recovery
	
	is_attacking = false

func _on_attack_area_body_entered(body: Node2D) -> void:
	print("=== PLAYER ATTACK HIT BODY ===")
	print("Body name: ", body.name)

	if body == self:
		print("Ignoring self-hit")
		return

	if body.is_in_group("boss"):
		print("PLAYER: Found boss via 'boss' group!'")
		if body.has_method("take_damage"):
			print("PLAYER: SUCCESS - Damaging BOSS!")
			body.take_damage(20, global_position)
		return

	if body.has_method("take_damage"):
		print("PLAYER: SUCCESS - Damaging via body!")
		body.take_damage(20, global_position)
	else:
		print("Body has no take_damage")


# ===== ANIMATION FINISHED EVENT =====
func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "Death":
		print("PLAYER: Death animation finished")

# ===== DAMAGE & HEALTH SYSTEM =====
func take_damage(damage, attacker_position = null):
	if is_hit or not can_take_damage or is_dead or is_invincible:
		print("PLAYER: Invincible - no damage taken")
		return
	
	can_take_damage = false
	print("PLAYER: Taking ", damage, " damage!")
	health -= damage
	healthChanged.emit()
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
	is_attacking = false
	
	$CollisionShape2D.set_deferred("disabled", true)
	attack_collision.set_deferred("disabled", true)
	
	velocity = Vector2.ZERO
	
	animated_sprite.play("Death")
	modulate = Color.DARK_RED
	
	await animated_sprite.animation_finished
	print("PLAYER: Death animation complete")
	
	await get_tree().create_timer(1.0).timeout
	
	respawn()

# ===== RESPAWN SYSTEM =====
func respawn():
	print("PLAYER: Respawning...")
	
	is_dead = false
	is_hit = false
	is_attacking = false
	health = 100
	can_take_damage = true
	
	$CollisionShape2D.disabled = false
	attack_collision.disabled = true
	
	modulate = Color.WHITE
	
	global_position = spawn_position
	velocity = Vector2.ZERO
	
	animated_sprite.play("Idle")
	
	activate_respawn_invincibility()
	
	print("PLAYER: Respawn complete! Health: ", health)

# ===== INVINCIBILITY SYSTEM =====
func activate_respawn_invincibility():
	is_invincible = true
	print("PLAYER: Invincibility ACTIVATED for ", respawn_invincibility_time, " seconds")
	
	var blink_timer = 0.0
	while blink_timer < respawn_invincibility_time:
		if modulate.a == 1.0:
			modulate = Color(1, 1, 1, 0.3)
		else:
			modulate = Color.WHITE
		
		await get_tree().create_timer(0.1).timeout
		blink_timer += 0.1
	
	is_invincible = false
	modulate = Color.WHITE
	print("PLAYER: Invincibility ENDED")

# ===== KNOCKBACK SYSTEM =====
func apply_knockback(attacker_position = null):
	print("PLAYER: Applying knockback")
	is_hit = true
	is_attacking = false
	
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
	
	for i in range(3):
		modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
	
	modulate = Color.WHITE
	is_hit = false
	print("PLAYER: Knockback finished")

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_E):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return
