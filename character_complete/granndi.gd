extends CharacterBody2D

@export var player: Node2D

# --------------------
# MOVEMENT & AI
# --------------------
var speed = 40
var move_direction = 1
var gravity = 900
var chase_distance = 200
var attack_distance = 50

# --------------------
# COMBAT
# --------------------
var health = 300
var is_dead = false
var is_attacking = false

# --------------------
# STATE
# --------------------
var state = "idle"

# --------------------
# NODES
# --------------------
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox/AttackCollision

# --------------------
# READY
# --------------------
func _ready():
	if not player:
		player = get_node("/root/MainScene/Player")

	attack_hitbox.disabled = true

# --------------------
# PHYSICS PROCESS
# --------------------
func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		if animated_sprite.animation != "Death":
			animated_sprite.play("Death")
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	var distance_to_player = global_position.distance_to(player.global_position)

	# --------------------
	# AI DECISION
	# --------------------
	if state == "attack" or state == "hurt":
		velocity.x = 0
	else:
		if distance_to_player > chase_distance:
			state = "idle"
			velocity.x = 0

		elif distance_to_player > attack_distance:
			state = "run"
			move_direction = 1 if player.global_position.x > global_position.x else -1
			velocity.x = speed * move_direction

		else:
			start_attack()

	# Flip sprite
	animated_sprite.flip_h = move_direction < 0

	move_and_slide()
	play_animation()

# --------------------
# ANIMATIONS
# --------------------
func play_animation():
	match state:
		"idle":
			animated_sprite.play("Idle")
		"run":
			animated_sprite.play("Run")
		"attack":
			animated_sprite.play("Attack")
		"hurt":
			animated_sprite.play("Hurt")
		"dead":
			animated_sprite.play("Death")

# --------------------
# ATTACK (ANIMATION LOCK)
# --------------------
func start_attack():
	if is_attacking:
		return

	is_attacking = true
	state = "attack"
	velocity.x = 0

	attack_hitbox.disabled = false

	# Animation lock for 1 second
	await get_tree().create_timer(1.5).timeout

	attack_hitbox.disabled = true
	is_attacking = false
	state = "run"

# --------------------
# HITBOX SIGNAL
# --------------------
func _on_AttackHitbox_body_entered(body):
	if body.name == "Player":
		body.take_damage(10)

# --------------------
# DAMAGE HANDLING
# --------------------
func take_damage(amount):
	if is_dead:
		return

	health -= amount

	if health <= 0:
		is_dead = true
		state = "dead"
		$CollisionShape2D.disabled = true
		$DeathCollision.disabled = false
	else:
		state = "hurt"
