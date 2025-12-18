extends CharacterBody2D

@export var player: Node2D

const SPEED = 40.0
const GRAVITY = 900.0
const CHASE_DISTANCE = 500.0
const ATTACK_DISTANCE = 50.0
const MAX_HEALTH = 100

var health = MAX_HEALTH
var is_dead = false
var is_attacking = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: CollisionShape2D = $AttackHitbox/AttackCollision
@onready var attack_area: Area2D = $AttackHitbox

func _ready() -> void:
	add_to_group("boss")

	attack_hitbox.disabled = true

	# NEW: stop player & boss from pushing each other
	if player:
		add_collision_exception_with(player)

	if not attack_area.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_area.body_entered.connect(_on_attack_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	if not player:
		move_and_slide()
		return

	var distance = global_position.distance_to(player.global_position)

	# Simple AI: idle, run, or attack
	if not is_attacking:
		if distance > CHASE_DISTANCE:
			velocity.x = 0
			animated_sprite.play("Idle")
		elif distance > ATTACK_DISTANCE:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED
			animated_sprite.play("Run")
		else:
			start_attack()

	# Flip sprite + hitbox towards player
	if player:
		var facing_left: bool = player.global_position.x < global_position.x
		animated_sprite.flip_h = facing_left

		var local_pos: Vector2 = attack_hitbox.position
		if facing_left:
			local_pos.x = -abs(local_pos.x)   # hitbox on left side
		else:
			local_pos.x = abs(local_pos.x)    # hitbox on right side
		attack_hitbox.position = local_pos

	move_and_slide()

func start_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	velocity.x = 0
	animated_sprite.play("Attack")

	await get_tree().create_timer(0.3).timeout   # windup

	attack_hitbox.disabled = false
	await get_tree().create_timer(0.2).timeout   # active

	attack_hitbox.disabled = true
	await get_tree().create_timer(0.3).timeout   # recovery

	is_attacking = false

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return

	var target = body
	if not target.is_in_group("player") and body.get_parent():
		target = body.get_parent()

	if target.is_in_group("player") and target.has_method("take_damage"):
		target.take_damage(10, global_position)

func take_damage(amount: int, _attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health -= amount
	print("BOSS: Damage ", amount, " | Health: ", health)

	if health <= 0:
		is_dead = true

		# Turn off all boss collisions so you can't drag him anymore
		$CollisionShape2D.disabled = true          # main body
		attack_hitbox.disabled = true              # attack hitbox
		if has_node("HurtBox/CollisionShape2D"):
			$HurtBox/CollisionShape2D.disabled = true

		animated_sprite.play("Death")
	else:
		animated_sprite.play("Hurt")
