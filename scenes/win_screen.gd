extends Control

@onready var main_menu: Button = $MarginContainer/PanelContainer/VBoxContainer/MainMenu
@onready var label: Label = $MarginContainer/PanelContainer/VBoxContainer/Label
@onready var win_type: Label = $MarginContainer/PanelContainer/VBoxContainer/WinType

func _ready() -> void:
	# Ocultamos la etiqueta vieja de KO/Checkmate ya que no aplica aquí
	if win_type:
		win_type.hide()
		
	main_menu.pressed.connect(_on_main_menu_pressed)

# Esta función la llamamos desde el agujero
func setup(is_winner: bool, winner_id: int) -> void:
	# 1. Traducir el ID enorme a un número simple (1, 2, 3...)
	var player_number = 1
	for i in range(Game.players.size()):
		if Game.players[i].id == winner_id:
			player_number = i + 1 # Sumamos 1 porque los índices empiezan en 0
			break

	# 2. Mostrar el texto correspondiente
	if is_winner:
		label.text = "¡HAS GANADO!"
		# Opcional: Color dorado para el ganador
		label.add_theme_color_override("font_color", Color.GOLD)
	else:
		# Aquí usamos el player_number en lugar del winner_id
		label.text = "¡HAS PERDIDO!\nEl Jugador " + str(player_number) + " metió la pelota."
		# Opcional: Color rojo para el perdedor
		label.add_theme_color_override("font_color", Color.CRIMSON)


func _on_main_menu_pressed() -> void:
	# 1. QUITAR LA PAUSA: Fundamental para que el menú principal 
	# y la siguiente partida no se queden congelados.
	get_tree().paused = false
	
	# 2. ARQUITECTURA MULTIJUGADOR: Apagar el peer de red local
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	# 3. Limpiar datos de jugadores
	Game.players = []
	
	# 4. Eliminar el CanvasLayer padre donde estamos montados
	var canvas_parent: Node = get_parent()
	if canvas_parent is CanvasLayer:
		canvas_parent.queue_free()
		
	# 5. Cambiar de escena
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
