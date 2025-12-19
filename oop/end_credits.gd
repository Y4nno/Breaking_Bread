extends Node2D

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	
	video_player.play()
	video_player.finished.connect(_on_video_finished)

func _on_video_finished() -> void:
	
	get_tree().change_scene_to_file("res://Assets/Scenes/Area/scene_1.tscn")
