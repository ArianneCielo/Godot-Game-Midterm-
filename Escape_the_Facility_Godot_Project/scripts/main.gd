extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DRONE_SCENE := preload("res://scenes/Drone.tscn")
const CORE_SCENE := preload("res://scenes/Core.tscn")

var player: CharacterBody2D
var score := 0
var best_score := 0
var health := 3
var cores_needed := 5
var won := false
var lost := false
var spawn_timer := 0.0
var core_timer := 0.0
var ui_label: Label
var hint_label: Label
var restart_button: Button
var exit_area: Area2D
var loading_next := false
var load_status := "Not started"

func _ready() -> void:
	randomize()
	_setup_input()
	_load_save()
	_build_facility()
	_spawn_player()
	_build_ui()
	_spawn_initial_cores()
	_spawn_drone()
	_update_ui()

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"restart": [KEY_R]
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _build_facility() -> void:
	# Outer walls and interior barriers are drawn and collision-tested here.
	var walls := [
		Rect2(0, 0, 960, 24), Rect2(0, 576, 960, 24),
		Rect2(0, 0, 24, 600), Rect2(936, 0, 24, 600),
		Rect2(180, 100, 24, 230), Rect2(360, 24, 24, 145),
		Rect2(520, 175, 24, 225), Rect2(700, 24, 24, 160),
		Rect2(180, 420, 240, 24), Rect2(610, 450, 200, 24)
	]
	for rect in walls:
		var body := StaticBody2D.new()
		body.position = rect.position + rect.size / 2.0
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)
		body.z_index = 1
	# Exit portal
	exit_area = Area2D.new()
	exit_area.position = Vector2(870, 510)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	cs.shape = circle
	exit_area.add_child(cs)
	add_child(exit_area)
	exit_area.body_entered.connect(_on_exit_body_entered)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = Vector2(75, 75)
	add_child(player)
	player.damaged.connect(_on_player_damaged)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.055, 0.10, 0.92)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(340, 118)
	
	

	ui_label = Label.new()
	ui_label.position = Vector2(36, 28)
	ui_label.add_theme_font_size_override("font_size", 18)
	ui_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	canvas.add_child(ui_label)

	hint_label = Label.new()
	hint_label.position = Vector2(25, 520)
	hint_label.size = Vector2(720, 60)
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color("#d8e7ff"))
	canvas.add_child(hint_label)

	restart_button = Button.new()
	restart_button.text = "Restart (R)"
	restart_button.position = Vector2(795, 25)
	restart_button.pressed.connect(_restart_game)
	canvas.add_child(restart_button)

func _spawn_initial_cores() -> void:
	var positions := [
		Vector2(280, 75), Vector2(450, 110), Vector2(800, 110),
		Vector2(275, 365), Vector2(625, 350), Vector2(820, 380),
		Vector2(420, 500), Vector2(110, 500)
	]
	for pos in positions:
		_spawn_core(pos)

func _spawn_core(pos: Vector2) -> void:
	var core := CORE_SCENE.instantiate()
	core.position = pos
	core.collected.connect(_on_core_collected)
	add_child(core)

func _spawn_drone() -> void:
	if won or lost:
		return
	var drone := DRONE_SCENE.instantiate()
	var spawn_points := [Vector2(850, 80), Vector2(600, 520), Vector2(450, 280), Vector2(80, 500)]
	drone.position = spawn_points[randi() % spawn_points.size()]
	drone.target = player
	add_child(drone)

func _process(delta: float) -> void:
	# Non-physics work: UI, spawn timers, and threaded loading status.
	if not won and not lost:
		spawn_timer += delta
		core_timer += delta
		if spawn_timer >= 5.0:
			spawn_timer = 0.0
			_spawn_drone()
		if core_timer >= 9.0 and get_tree().get_nodes_in_group("cores").size() < 3:
			core_timer = 0.0
			_spawn_core(Vector2(randf_range(70, 880), randf_range(70, 530)))
	if Input.is_action_just_pressed("restart"):
		_restart_game()
	if loading_next:
		var status := ResourceLoader.load_threaded_get_status("res://scenes/Sector2.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get("res://scenes/Sector2.tscn")
			loading_next = false
			if packed:
				hint_label.text = "Sector resource loaded in background! Facility secured."
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading_next = false
			hint_label.text = "Could not load next sector. You can keep playing."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if player and player.global_position.distance_to(exit_area.global_position) < 80:
			_try_escape()

func _on_core_collected(points: int) -> void:
	if won or lost:
		return
	score += points
	_update_ui()

func _on_player_damaged() -> void:
	if won or lost:
		return
	health -= 1
	_update_ui()
	if health <= 0:
		lost = true
		hint_label.text = "SYSTEM FAILURE — Press R to try again."

func _on_exit_body_entered(body: Node2D) -> void:
	if body == player and score >= cores_needed * 10:
		_try_escape()

func _try_escape() -> void:
	if score < cores_needed * 10:
		hint_label.text = "Exit locked! Collect at least 5 energy cores first."
		return
	if won or lost:
		return
	won = true
	best_score = max(best_score, score)
	_save_game()
	hint_label.text = "YOU ESCAPED! Best score saved. Press R to play again."
	# Demonstrate threaded loading without blocking the main thread.
	var error := ResourceLoader.load_threaded_request("res://scenes/Sector2.tscn")
	loading_next = error == OK
	_update_ui()

func _update_ui() -> void:
	if ui_label:
		ui_label.text = "ESCAPE THE FACILITY!              Energy: %d / %d           Lives: %d            Best: %d" % [score / 10, cores_needed, health, best_score]

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_score", best_score)
	config.save("user://save_data.cfg")

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://save_data.cfg") == OK:
		best_score = int(config.get_value("progress", "best_score", 0))

func _draw() -> void:
	# Dark facility floor and neon grid.
	draw_rect(Rect2(0, 0, 960, 600), Color("#101b2b"))
	for x in range(24, 936, 40):
		draw_line(Vector2(x, 24), Vector2(x, 576), Color(0.16, 0.29, 0.42, 0.30), 1)
	for y in range(24, 576, 40):
		draw_line(Vector2(24, y), Vector2(936, y), Color(0.16, 0.29, 0.42, 0.30), 1)
	var walls := [
		Rect2(0, 0, 960, 24), Rect2(0, 576, 960, 24),
		Rect2(0, 0, 24, 600), Rect2(936, 0, 24, 600),
		Rect2(180, 100, 24, 230), Rect2(360, 24, 24, 145),
		Rect2(520, 175, 24, 225), Rect2(700, 24, 24, 160),
		Rect2(180, 420, 240, 24), Rect2(610, 450, 200, 24)
	]
	for rect in walls:
		draw_rect(rect, Color("#29465e"))
		draw_rect(rect.grow(-4), Color("#1c3044"))
	# Exit portal, colored according to whether unlocked.
	var exit_color := Color("#48f0b4") if score >= cores_needed * 10 else Color("#586a8a")
	draw_circle(Vector2(870, 510), 27, exit_color)
	draw_circle(Vector2(870, 510), 18, Color("#101b2b"))
	draw_circle(Vector2(870, 510), 10, exit_color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		queue_redraw()
