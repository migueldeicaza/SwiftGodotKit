extends CanvasLayer

signal start_game


func show_message(text: String) -> void:
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start()


func show_game_over() -> void:
	show_message("Game over")
	await $MessageTimer.timeout
	$MessageLabel.text = "Save the\nAxolotl"
	$MessageLabel.show()
	await get_tree().create_timer(1.0).timeout
	$StartButton.show()


func update_score(value: int) -> void:
	$ScoreLabel.text = str(value)


func _on_start_button_pressed() -> void:
	$StartButton.hide()
	start_game.emit()


func _on_message_timer_timeout() -> void:
	$MessageLabel.hide()
