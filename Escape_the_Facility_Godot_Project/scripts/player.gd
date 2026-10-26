extends CharacterBody2D

signal damaged

@export var speed: float = 230.0
var invulnerable := false

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

func take_damage() -> void:
	if invulnerable:
		return
	invulnerable = true
	damaged.emit()
	await get_tree().create_timer(1.0).timeout
	invulnerable = false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color("#55d9ff"))
	draw_circle(Vector2(0, -2), 7.0, Color("#d9f8ff"))
	draw_circle(Vector2(-3, -2), 1.8, Color("#15304b"))
	draw_circle(Vector2(3, -2), 1.8, Color("#15304b"))
