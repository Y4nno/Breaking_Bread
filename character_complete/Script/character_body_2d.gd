extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 200
const JUMP_POWER = -350.0
var gravity = 900

var is_attacking = false  # added for attack state
var weapon_equip: bool

var attack_timer = 0.0
var ATTACK_DURATION = 0.3 

func _ready():
	weapon_equip = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_POWER

	# Detect attack input (left click)
	if Input.is_action_just_pressed("mouse_attack"):
		attack()

	# Movement is always allowed
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	handle_movement_animation(direction)

func handle_movement_animation(dir):
	# Only skip if attack animation is currently playing
	var sprite_frames = animated_sprite.sprite_frames  # correct property in Godot 4
	if animated_sprite.animation == "Single Attack" and animated_sprite.frame < sprite_frames.get_frame_count("Single Attack") - 1:
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
	if dir == 1:
		animated_sprite.flip_h = false
	if dir == -1:
		animated_sprite.flip_h = true

# Attack function
func attack():
	is_attacking = true
	animated_sprite.play("Single Attack")  # restart attack animation every click

# Animation finished signal

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "Single Attack":
		is_attacking = false
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.play("Idle")
