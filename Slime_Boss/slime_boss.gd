extends CharacterBody2D
class_name SlimeBoss

# =========================
# CONSTANTS
# =========================
const SPEED: float = 30.0
const GRAVITY: float = 900.0
const CHASE_RANGE: float = 220.0
const ATTACK_RANGE: float = 60.0
const ATTACK_COOLDOWN: float = 1.5
const KNOCKBACK_FORCE: float = 300.0

# =========================
# STATS
# =========================
var health: int = 300
var max_health: int = 300
var damage_to_deal: int = 20

var dead: bool = false
var is_chasing: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var taking_damage: bool = false

# =========================
# NODE REFERENCES
# =========================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

# =========================
# TARGET
# =========================
var player: CharacterBody2D = null

# =========================
# READY
# =========================
func _ready():
	add_to_group("boss")
	
	# Connect attack area signal
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	attack_collision.disabled = true
	attack_area.monitoring = false
	
	# Get player reference
	if get_tree().has_group("player"):
		player = get_tree().get_first_node_in_group("player")

# =========================
# PHYSICS PROCESS
# =========================
func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		sprite.play("idle")
		move_and_slide()
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	check_player_distance()
	handle_movement()
	handle_animation()

	move_and_slide()

# =========================
# PLAYER DETECTION
# =========================
func check_player_distance() -> void:
	if not player:
		return

	var dist: float = global_position.distance_to(player.global_position)
	is_chasing = dist <= CHASE_RANGE

	if dist <= ATTACK_RANGE and can_attack:
		attack()

# =========================
# MOVEMENT
# =========================
func handle_movement() -> void:
	if is_attacking:
		velocity.x = 0
		return

	if is_chasing and player:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity.x = dir.x * SPEED
	else:
		velocity.x = 0

# =========================
# ATTACK
# =========================
func attack() -> void:
	if is_attacking or dead:
		return

	is_attacking = true
	can_attack = false
	velocity.x = 0
	sprite.play("attack")

	# Wind-up frames
	await get_tree().create_timer(0.4).timeout

	# Enable attack hitbox
	attack_collision.disabled = false
	attack_area.monitoring = true

	# Active frames
	await get_tree().create_timer(0.25).timeout

	# Disable attack hitbox
	attack_collision.disabled = true
	attack_area.monitoring = false

	is_attacking = false

	# Cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

# =========================
# ATTACK SIGNAL
# =========================
func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_to_deal, global_position)

# =========================
# ANIMATION
# =========================
func handle_animation() -> void:
	if is_attacking or dead:
		return

	if abs(velocity.x) > 1.0:
		sprite.play("walk")
	else:
		sprite.play("idle")

	sprite.flip_h = velocity.x < 0

# =========================
# DAMAGE
# =========================
func take_damage(amount: int, attacker_position: Vector2) -> void:
	if dead or taking_damage:
		return

	taking_damage = true
	health -= amount

	# Apply knockback
	var knock_dir: Vector2 = (global_position - attacker_position).normalized()
	velocity.x = knock_dir.x * KNOCKBACK_FORCE
	velocity.y = knock_dir.y * KNOCKBACK_FORCE

	# Flash red
	sprite.modulate = Color.RED

	if health <= 0:
		die()
	else:
		await get_tree().create_timer(0.3).timeout
		sprite.modulate = Color.WHITE
		taking_damage = false

# =========================
# DEATH
# =========================
func die() -> void:
	dead = true
	is_attacking = false
	attack_collision.disabled = true
	attack_area.monitoring = false
	velocity = Vector2.ZERO
	sprite.play("death")

	await sprite.animation_finished
	queue_free()
