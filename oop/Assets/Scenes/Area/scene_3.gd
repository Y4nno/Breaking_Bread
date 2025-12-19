extends Node2D   # or whatever your arena root is

func _ready() -> void:
	print("Arena: connecting boss_defeated")
	$Granndi.boss_defeated.connect(_on_boss_defeated)
	# If your boss node path is different, e.g. $Enemies/Granndi, use that exact path

func _on_boss_defeated() -> void:
	print("Arena: received boss_defeated, changing to EndCredits")
	get_tree().change_scene_to_file("res://End_Credits.tscn")
	# Change this string to the real path of EndCredits.tscn in your project
