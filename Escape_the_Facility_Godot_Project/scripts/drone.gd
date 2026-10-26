extends CharacterBody2D

signal touched_player

var target: Node2D
var speed: float = 75.0
var life_left: float = 24.0

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	if is_instance_valid(target):
		var direction := global_position.direction_to(target.global_position)
		velocity = direction * speed
		move_and_slide()
		if global_position.distance_to(target.global_position) < 25.0:
			if target.has_method("take_damage"):
				target.take_damage()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color("#ff5964"))
	draw_circle(Vector2(-4, -3), 3.0, Color("#fff2cc"))
	draw_circle(Vector2(4, -3), 3.0, Color("#fff2cc"))
	draw_line(Vector2(-7, 5), Vector2(7, 5), Color("#5b101b"), 2.0)
