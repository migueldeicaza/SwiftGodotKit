extends Area2D

signal hit

@export var speed := 400.0

var screen_size := Vector2.ZERO
var touch_active := false
var touch_target := Vector2.ZERO


func _ready() -> void:
	screen_size = get_viewport_rect().size
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		touch_target = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		touch_active = true
		touch_target = event.position
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var velocity = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if velocity == Vector2.ZERO and touch_active:
		var offset = touch_target - position
		if offset.length() > 8.0:
			velocity = offset.normalized()

	if velocity.length() > 0.0:
		velocity = velocity.normalized() * speed
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()

	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)

	if velocity.x != 0.0:
		rotation = 0.0
		$AnimatedSprite2D.animation = &"right"
		$AnimatedSprite2D.flip_h = velocity.x < 0.0
	elif velocity.y != 0.0:
		$AnimatedSprite2D.animation = &"up"
		$AnimatedSprite2D.flip_h = false
		rotation = PI if velocity.y > 0.0 else 0.0


func start(start_position: Vector2) -> void:
	position = start_position
	rotation = 0.0
	touch_active = false
	show()
	$CollisionShape2D.disabled = false


func _on_body_entered(_body: Node) -> void:
	hide()
	touch_active = false
	hit.emit()
	$CollisionShape2D.set_deferred(&"disabled", true)
