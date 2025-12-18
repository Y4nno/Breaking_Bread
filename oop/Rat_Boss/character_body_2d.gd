extends CharacterBody2D
class_name RatBoss

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $"Detection Area"
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

const SPEED := 120
const GRAVITY := 900
const ATTACK_DAMAGE := 30
const ATTACK_COOLDOWN := 1.2
const ATTACK_RANGE := 70

var health := 100
var max_health := 450
var dead := false
var is_attacking := false
var can_take_damage := true

var player: CharacterBody2D = null
var knockback_force := 420

func _ready():
	add_to_group("boss")
	attack_shape.disabled = true
	detection_area.body_entered.connect(_on_detection_body_entered)
	attack_area.body_entered.connect(_on_attack_body_entered)

func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	if player and not is_attacking:
		var dir: int = int(sign(player.global_position.x - global_position.x))
		velocity.x = dir * SPEED
		sprite.flip_h = dir > 0

		if abs(player.global_position.x - global_position.x) <= ATTACK_RANGE:
			attack()
	else:
		velocity.x = 0

	move_and_slide()

# =====================
# ATTACK
# =====================
func attack():
	if is_attacking or dead:
		return

	is_attacking = true
	velocity.x = 0
	sprite.play("Attack")

	# Wind-up
	await get_tree().create_timer(0.25).timeout

	# Enable hitbox
	attack_shape.disabled = false

	# Active frames
	await get_tree().create_timer(0.2).timeout

	# Disable hitbox
	attack_shape.disabled = true

	# Recovery
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	is_attacking = false

# =====================
# DAMAGE PLAYER
# =====================
func _on_attack_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE, global_position)

# =====================
# DETECTION
# =====================
func _on_detection_body_entered(body):
	if body.is_in_group("player"):
		player = body

func take_damage(amount: int, attacker_position := Vector2.ZERO):
	if dead or not can_take_damage:
		return

	can_take_damage = false
	health -= amount
	sprite.modulate = Color.RED

	apply_knockback(attacker_position)

	if health <= 0:
		die()

	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color.WHITE
	can_take_damage = true

# =====================
# KNOCKBACK
# =====================
func apply_knockback(attacker_position):
	var dir: int = int(sign(global_position.x - attacker_position.x))
	velocity.x = dir * knockback_force
	velocity.y = -150
	move_and_slide()

func die():
	dead = true
	sprite.play("Death")
	attack_shape.disabled = true
	$CollisionShape2D.disabled = true
	await sprite.animation_finished
	queue_free()
