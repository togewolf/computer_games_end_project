extends CanvasLayer

# Esc toggles pause. Hidden by default; process_mode is ALWAYS so it
# keeps receiving input while the tree is paused.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Don't allow pausing over the game over screen
		var game_over = get_parent().get_node_or_null("GameOverLayer")
		if game_over and game_over.visible:
			return
		_set_paused(not visible)


func _set_paused(paused: bool) -> void:
	visible = paused
	get_tree().paused = paused


func _on_continue_pressed() -> void:
	_set_paused(false)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")
