extends Area2D

signal collected(points: int)

var bob_time := 0.0

func _ready() -> void:
	add_to_group("cores")
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	bob_time += delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(bob_time * 3.0) * 3.0
	var diamond := PackedVector2Array([Vector2(0, -11 + bob), Vector2(8, bob), Vector2(0, 11 + bob), Vector2(-8, bob)])
	draw_colored_polygon(diamond, Color("#ffd84d"))
	draw_circle(Vector2(0, bob), 3.0, Color("#fff8c7"))

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		collected.emit(10)
		queue_free()
