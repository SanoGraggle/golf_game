extends RigidBody2D

@export var ball_color: Color = Color.WHITE
@onready var sprite: Sprite2D = $Sprite2D

# Nueva variable para recordar dónde estaba en el fotograma anterior
var last_position: Vector2

func _ready() -> void:
	add_to_group("balls")
	gravity_scale = 0
	
	# Guardamos la posición inicial para evitar saltos
	last_position = position
	
	if not multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true

func _process(_delta: float) -> void:
	if sprite and sprite.self_modulate != ball_color:
		sprite.self_modulate = ball_color
		
	# --- LÓGICA DE ROTACIÓN DEL SPRITE ---
	# 1. Calculamos qué tanta distancia avanzó desde el último fotograma
	var distance_moved = position.distance_to(last_position)
	
	# 2. Si se movió lo suficiente (evitamos micro-vibraciones), rotamos el sprite
	if distance_moved > 0.05:
		# Multiplica 'distance_moved' por un valor (ej: 0.1) para ajustar la velocidad de giro.
		# A mayor número, girará más rápido.
		sprite.rotation += distance_moved * 0.1 
		
	# 3. Actualizamos la posición guardada para el siguiente fotograma
	last_position = position

@rpc("any_peer", "call_local", "reliable")
func request_hit(impulse_direction: Vector2, power: float) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	var owner_string_id = name.replace("Ball_", "")
	var owner_id = owner_string_id.to_int()
		
	if sender_id != owner_id:
		print("Rechazado. Petición de: ", sender_id, " Dueño real: ", owner_id)
		return
	 	
	if multiplayer.is_server():
		var final_impulse = impulse_direction.normalized() * power
		freeze = false 
		apply_central_impulse(final_impulse)
 
