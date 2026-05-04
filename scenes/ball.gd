extends RigidBody2D

func _ready() -> void:
	gravity_scale = 0
	
	if is_multiplayer_authority():
		# El servidor le da el impulso inicial
		await get_tree().process_frame # Esperar a que la escena cargue bien
		apply_central_impulse(Vector2(300, 300))
	else:
		# Los clientes NO calculan física, solo sincronizan posición
		# Esto evita que la pelota "tiemble" o se desincronice
		freeze = true
