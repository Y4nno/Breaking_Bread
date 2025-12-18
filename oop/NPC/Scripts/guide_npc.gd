extends CharacterBody2D

# Get references to the AnimatedSprite2D node
@onready var animated_sprite = $animated_guide
var speed = 100 # Example movement speed

func _physics_process(_delta):
	
		animated_sprite.play("idle")
