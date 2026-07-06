class_name MainMenu
extends Control


@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var credits: Button = %Credits
@onready var how_to_play: Button = %HowToPlay
@onready var quit: Button = %Quit
@onready var golf_ball: TextureRect = %GolfBall
@onready var how_to_play_panel: PanelContainer = %HowToPlayPanel
@onready var back_button: Button = %BackButton

var _time: float = 0.0
var _ball_start_pos: Vector2


func _ready() -> void:
	if Game.multiplayer_test:
		get_tree().call_deferred("change_scene_to_file", "res://lobby/lobby_test.tscn")
		return
	
	quit.pressed.connect(func() -> void: get_tree().quit())
	host.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	credits.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/credits.tscn"))
	how_to_play.pressed.connect(_show_how_to_play)
	back_button.pressed.connect(_hide_how_to_play)
	
	host.grab_focus()
	
	_ball_start_pos = golf_ball.position
	
	_play_entrance_animations()
	
	for button: Button in [host, join, credits, how_to_play, quit, back_button]:
		button.mouse_entered.connect(func() -> void: _on_button_hover(button))
		button.mouse_exited.connect(func() -> void: _on_button_unhover(button))


func _process(delta: float) -> void:
	_time += delta
	
	# Golf ball gentle bob
	golf_ball.position.y = _ball_start_pos.y + sin(_time * 2.0) * 6.0
	golf_ball.rotation = sin(_time * 1.5) * 0.05


func _play_entrance_animations() -> void:
	# Title fade in
	var title_container: VBoxContainer = $TitleSection
	title_container.modulate.a = 0.0
	var tween_title: Tween = create_tween()
	tween_title.tween_property(title_container, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	
	# Golf ball bounce in
	golf_ball.scale = Vector2.ZERO
	var tween_ball: Tween = create_tween()
	tween_ball.tween_property(golf_ball, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.3)
	
	# Buttons slide in from below
	var button_container: VBoxContainer = $ButtonSection
	var original_pos: float = button_container.position.y
	button_container.position.y += 60.0
	button_container.modulate.a = 0.0
	var tween_buttons: Tween = create_tween()
	tween_buttons.set_parallel(true)
	tween_buttons.tween_property(button_container, "position:y", original_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(0.5)
	tween_buttons.tween_property(button_container, "modulate:a", 1.0, 0.4).set_delay(0.5)


func _on_button_hover(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)


func _on_button_unhover(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)


func _show_how_to_play() -> void:
	how_to_play_panel.visible = true
	how_to_play_panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(how_to_play_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	back_button.grab_focus()


func _hide_how_to_play() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(how_to_play_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: how_to_play_panel.visible = false)
	host.grab_focus()
