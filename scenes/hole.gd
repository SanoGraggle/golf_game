extends Area2D

# Asegúrate de poner la ruta correcta hacia tu escena win_screen.tscn
var win_screen_scene = preload("res://scenes/win_screen.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("balls"):
		var winner_id = body.name.replace("Ball_", "").to_int()
		
		# Llamamos al RPC para todos
		announce_winner.rpc(winner_id)
		body.queue_free()

@rpc("authority", "call_local", "reliable")
func announce_winner(winner_id: int) -> void:
	var my_id = multiplayer.get_unique_id()
	var am_i_winner = (my_id == winner_id)
	
	# 1. Instanciar la pantalla de victoria
	var win_screen_instance = win_screen_scene.instantiate()
	
	# 2. Crear el CanvasLayer y armar la jerarquía
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	canvas.add_child(win_screen_instance)
	
	# 3. AÑADIR AL ÁRBOL PRIMERO (Esto dispara el _ready() y carga los @onready)
	get_tree().root.add_child(canvas)
	
	# 4. AHORA SÍ llamamos a setup, porque los Labels ya existen en la memoria
	win_screen_instance.setup(am_i_winner, winner_id)
	
	# 5. Pausar el juego (Opcional)
	get_tree().paused = true
