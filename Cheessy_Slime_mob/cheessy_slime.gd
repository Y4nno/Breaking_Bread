extends CharacterBody2D
class_name ChessySlime

const SPEED := 40
const GRAVITY := 900
const CHASE_RANGE := 120

var is_slime_chase: bool = false
var is_roaming: bool = true
var dead: bool = false

var health := 50
var damage_to_deal := 10
var knockback_force := 200

var dir: Vector2 = Vector2.ZERO
var player: CharacterBody2D

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	check_for_player()
	move(delta)
	move_and_slide()

func check_for_player():
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)
	is_slime_chase = distance <= CHASE_RANGE

func move(delta):
	if is_slime_chase and player:
		is_roaming = false
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * SPEED
	else:
		is_roaming = true
		velocity.x = dir.x * SPEED

func _on_direction_timer_timeout():
	$DirectionTimer.wait_time = choose([1.5, 2.0, 2.5])

	if not is_slime_chase and not dead:
		dir = choose([Vector2.LEFT, Vector2.RIGHT])

func choose(array):
	array.shuffle()
	return array.front()
