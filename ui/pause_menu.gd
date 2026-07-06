extends CanvasLayer

@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var exit_button: Button = %ExitButton
@onready var main_panel: VBoxContainer = %MainPanel
@onready var options_panel: VBoxContainer = %OptionsPanel
@onready var options_back_button: Button = %OptionsBackButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel

var _is_paused: bool = false


func _ready() -> void:
	pause_panel.visible = false
	options_panel.visible = false
	resume_button.pressed.connect(_resume)
	options_button.pressed.connect(_show_options)
	options_back_button.pressed.connect(_hide_options)
	exit_button.pressed.connect(_exit_to_menu)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	# Inicializar el slider con el volumen actual del bus Master
	var bus_index: int = AudioServer.get_bus_index("Master")
	var current_db: float = AudioServer.get_bus_volume_db(bus_index)
	volume_slider.value = db_to_linear(current_db)
	_update_volume_label(volume_slider.value)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	# Solo pausar si estamos en una escena de juego (no en menús)
	var current_scene: Node = get_tree().current_scene
	if current_scene is MainMenu or current_scene is Credits:
		return
	if current_scene is LobbyHostScreen or current_scene is LobbyJoinScreen:
		return
	if current_scene is LobbyWaitingScreen:
		return
	
	_is_paused = true
	pause_panel.visible = true
	main_panel.visible = true
	options_panel.visible = false
	resume_button.grab_focus()


func _resume() -> void:
	_is_paused = false
	pause_panel.visible = false
	options_panel.visible = false


func _show_options() -> void:
	main_panel.visible = false
	options_panel.visible = true
	options_back_button.grab_focus()


func _hide_options() -> void:
	options_panel.visible = false
	main_panel.visible = true
	options_button.grab_focus()


func _exit_to_menu() -> void:
	_is_paused = false
	pause_panel.visible = false
	
	# Eliminar cualquier CanvasLayer de win_screen que pueda estar flotando
	for child: Node in get_tree().root.get_children():
		if child is CanvasLayer and child != self and child.name != "Game" and child.name != "Lobby" and child.name != "PauseMenu":
			for subchild: Node in child.get_children():
				if subchild.has_method("setup"):
					child.queue_free()
					break
	
	Lobby.go_to_menu()


func _on_volume_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if value <= 0.01:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_label.text = str(int(value * 100)) + "%"
