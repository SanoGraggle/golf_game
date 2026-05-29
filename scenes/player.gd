# player.gd
extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -400.0

@export var player_color: Color = Color.WHITE # Nueva variable sincronizada
@onready var sprite: Sprite2D = $Sprite2D # Asegúrate de que el nombre coincida con tu nodo Sprite2D
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var camera: Camera2D = $Camera2D

func _process(_delta: float) -> void:
	# Sincronizamos el color visualmente en todos los clientes
	if sprite and sprite.self_modulate != player_color:
		sprite.self_modulate = player_color

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		var direction_x := Input.get_axis("ui_left", "ui_right")
		var direction_y := Input.get_axis("ui_up", "ui_down")

		velocity.x = direction_x * SPEED if direction_x else move_toward(velocity.x, 0, SPEED)
		velocity.y = direction_y * SPEED if direction_y else move_toward(velocity.y, 0, SPEED)
		
		if Input.is_action_just_pressed("ui_accept"):
			var shot_direction = velocity.normalized()
			if shot_direction == Vector2.ZERO:
				shot_direction = Vector2.UP 
			shoot_my_ball(shot_direction, 500.0)

	move_and_slide()
	
func setup(data: Statics.PlayerData) -> void:
	name = str(data.id)
	set_multiplayer_authority(data.id, false)
	multiplayer_synchronizer.set_multiplayer_authority(data.id, false)
	# Activar la cámara solo para el jugador local (debe ser después de set_multiplayer_authority)
	camera.enabled = is_multiplayer_authority()

func shoot_my_ball(direction: Vector2, power: float) -> void:
	var my_id = multiplayer.get_unique_id()
	
	# Construimos el nombre exacto que le dimos a la pelota en el servidor
	var target_ball_name = "Ball_" + str(my_id)
	var balls = get_tree().get_nodes_in_group("balls")
	
	for ball in balls:
		if ball.name == target_ball_name:
			# Pelota encontrada de forma garantizada, enviamos RPC
			ball.request_hit.rpc(direction, power)
			return # Terminamos la función
			
	print("Error: No encontré mi pelota con el nombre: ", target_ball_name)
