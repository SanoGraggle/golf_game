extends Area2D

func _ready() -> void:
	# Conectamos la señal que detecta cuando un cuerpo entra al área
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# REGLA DE ORO: Solo el servidor valida quién entra al agujero
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("balls"):
		# Extraemos el ID del ganador directamente del nombre de la pelota
		var winner_string_id = body.name.replace("Ball_", "")
		var winner_id = winner_string_id.to_int()
		
		# Le decimos a TODOS los clientes (y al propio servidor local) quién ganó
		announce_winner.rpc(winner_id)
		
		# Opcional: Eliminar la pelota para que no vuelva a chocar
		body.queue_free()

# Este RPC solo lo puede llamar el servidor ("authority"), 
# pero se ejecuta en las pantallas de todos ("call_local")
@rpc("authority", "call_local", "reliable")
func announce_winner(winner_id: int) -> void:
	var my_id = multiplayer.get_unique_id()
	
	if my_id == winner_id:
		print("¡Felicidades! Metiste la pelota y GANASTE LA PARTIDA.")
	else:
		print("Fin del juego. El ganador es el jugador: ", winner_id)
		
		# --- AQUÍ IRÁ TU LÓGICA VISUAL ---
	# Ejemplo: Mostrar un panel que diga "Victoria", detener el movimiento 
	# de los jugadores, o mostrar un botón de "Volver al Menú Principal".
