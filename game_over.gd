extends CanvasLayer

# Shown when either wizard's health reaches 0.
# Pauses the game so projectiles/agent stop while the overlay is up.


func show_result(player_won: bool) -> void:
	if visible:
		return # already showing
	visible = true
	get_tree().paused = true
	var label: Label = $Panel/Result
	if player_won:
		label.text = "VICTORY!"
		label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	else:
		label.text = "DEFEAT"
		label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")
