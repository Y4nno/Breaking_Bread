extends Node
var current_area = 1
var area_path = "res://Assets/Scenes/Area/"


func next_level():
	current_area += 1
	var full_path = area_path + "scene_" + str(current_area) + ".tscn"
	get_tree().change_scene_to_file(full_path)
	print("Player has touched")
