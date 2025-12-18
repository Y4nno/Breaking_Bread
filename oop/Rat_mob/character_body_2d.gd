extends CharacterBody2D
class_name RatMob

const SPEED := 50
const GRAVITY := 900
const CHASE_RANGE := 120
const KNOCKBACK_FORCE := 200

var is_chasing := false
var is_roaming := true
var dead := false

var health := 30
var damage_to_deal := 5

var dir: Vector2 = Vector2.ZERO
var player: CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		sprite.play("idle")
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	check_for_player()
	move()
	update_animation()
	move_and_slide()

func check_for_player():
	if not player:
		return
	var distance = global_position.distance_to(player.global_position)
	is_chasing = distance <= CHASE_RANGE

func move():
	if is_chasing and player:
		is_roaming = false
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * SPEED
	else:
		is_roaming = true
		velocity.x = dir.x * SPEED

func update_animation():
	if abs(velocity.x) > 1:
		sprite.play("walk")
	else:
		sprite.play("idle")

	# Flip sprite
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

func _on_DirectionTimer_timeout():
	$DirectionTimer.wait_time = choose([1.5, 2.0, 2.5])
	if not is_chasing and not dead:
		dir = choose([Vector2.LEFT, Vector2.RIGHT])

func take_damage(amount: int, from_pos: Vector2):
	health -= amount
	var knock_dir = (global_position - from_pos).normalized()
	velocity += knock_dir * KNOCKBACK_FORCE

	if health <= 0:
		die()

func die():
	dead = true
	sprite.play("idle")  # You can add a death animation later

func choose(array):
	array.shuffle()
	return array.front()
