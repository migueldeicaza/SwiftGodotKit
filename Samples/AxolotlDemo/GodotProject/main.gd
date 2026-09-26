extends Node

@export var mob_scene: PackedScene

var score := 0


func _ready() -> void:
	randomize()


func game_over() -> void:
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over()
	$Music.stop()
	$DeathSound.play()


func new_game() -> void:
	get_tree().call_group(&"mobs", &"queue_free")
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get ready")
	$Music.play()


func _on_mob_timer_timeout() -> void:
	var mob = mob_scene.instantiate()
	var spawn_location = $MobPath/MobSpawnLocation
	spawn_location.progress_ratio = randf()
	mob.position = spawn_location.position

	var direction = spawn_location.rotation + PI / 2.0
	direction += randf_range(-PI / 4.0, PI / 4.0)
	mob.rotation = direction
	mob.linear_velocity = Vector2(randf_range(150.0, 250.0), 0.0).rotated(direction)
	add_child(mob)


func _on_score_timer_timeout() -> void:
	score += 1
	$HUD.update_score(score)


func _on_start_timer_timeout() -> void:
	$MobTimer.start()
	$ScoreTimer.start()
