extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		# Capturamos ambas direcciones
		var direction_x := Input.get_axis("ui_left", "ui_right")
		var direction_y := Input.get_axis("ui_up", "ui_down")

		# Movimiento en X
		if direction_x:
			velocity.x = direction_x * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		# Movimiento en Y
		if direction_y:
			velocity.y = direction_y * SPEED
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)

	# move_and_slide debe estar fuera del if de autoridad para que
	# se sincronice correctamente en todos los clientes
	move_and_slide()
	#send_position.rpc(global_position)
	
func setup(data: Statics.PlayerData) -> void:
	name = str(data.id)
	set_multiplayer_authority(data.id, false)
	multiplayer_synchronizer.set_multiplayer_authority(data.id, false)

@rpc("authority", "call_remote", "unreliable_ordered")
func send_position(pos: Vector2) -> void:
	global_position = pos
