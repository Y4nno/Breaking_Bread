extends CharacterBody2D
class_name SlimeBoss

const SPEED := 30
const GRAVITY := 900
const CHASE_RANGE := 220
const ATTACK_RANGE := 60
const ATTACK_COOLDOWN := 1.5
const KNOCKBACK_FORCE := 300

var health := 300
var max_health := 300
var damage_to_deal := 20

var dead := false
var is_chasing := false
var is_attacking := false
var can_attack := true
var taking_damage := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

var player: CharacterBody2D

func _ready():
	add_to_group("boss")
	player = get_tree().get_first_node_in_group("player")

	attack_collision.disabled = true
	attack_area.monitoring = false

func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		sprite.play("idle")
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	check_player_distance()
	handle_movement()
	handle_animation()

	move_and_slide()

func check_player_distance():
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	is_chasing = dist <= CHASE_RANGE

	if dist <= ATTACK_RANGE and can_attack:
		attack()

func handle_movement():
	if is_attacking:
		velocity.x = 0
		return

	if is_chasing and player:
		var dir = (player.global_position - global_position).normalized()
		velocity.x = dir.x * SPEED
	else:
		velocity.x = 0

func attack():
	if is_attacking or dead:
		return

	is_attacking = true
	can_attack = false

	sprite.play("attack")

	# Wind-up (telegraph)
	await get_tree().create_timer(0.4).timeout

	# Enable hitbox
	attack_collision.disabled = false
	attack_area.monitoring = true

	await get_tree().create_timer(0.25).timeout

	# Disable hitbox
	attack_collision.disabled = true
	attack_area.monitoring = false

	is_attacking = false

	# Cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

func _on_AttackArea_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage_to_deal, global_position)

func handle_animation():
	if is_attacking:
		return

	if abs(velocity.x) > 1:
		sprite.play("walk")
	else:
		sprite.play("idle")

	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

func take_damage(amount: int, attacker_position: Vector2):
	if dead or taking_damage:
		return

	taking_damage = true
	health -= amount

	# Knockback
	var knock_dir = (global_position - attacker_position).normalized()
	velocity += knock_dir * KNOCKBACK_FORCE

	sprite.modulate = Color.RED

	if health <= 0:
		die()

	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color.WHITE
	taking_damage = false

func die():
	dead = true
	sprite.play("death")
	attack_collision.disabled = true
	attack_area.monitoring = false
	velocity = Vector2.ZERO
