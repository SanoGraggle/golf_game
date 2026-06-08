# player.gd
extends CharacterBody2D

const SPEED = 150.0

@export var player_color: Color = Color.WHITE # Nueva variable sincronizada
@onready var sprite: Sprite2D = $Sprite2D # Asegúrate de que el nombre coincida con tu nodo Sprite2D
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var camera: Camera2D = $Camera2D

@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer	

func _process(_delta: float) -> void:
	# Sincronizamos el color visualmente en todos los clientes
	if sprite and sprite.self_modulate != player_color:
		sprite.self_modulate = player_color

func _physics_process(_delta: float) -> void:
	var move_input: Vector2 = input_synchronizer.move_input

	velocity.x = move_input.x * SPEED if move_input.x else move_toward(velocity.x, 0, SPEED)
	velocity.y = move_input.y * SPEED if move_input.y else move_toward(velocity.y, 0, SPEED)

	move_and_slide()

	if is_multiplayer_authority():
		handle_shot_input()

	
func setup(data: Statics.PlayerData) -> void:
	name = str(data.id)
	set_multiplayer_authority(data.id, false)
	multiplayer_synchronizer.set_multiplayer_authority(data.id, false)
	# Activar la cámara solo para el jugador local (debe ser después de set_multiplayer_authority)
	camera.enabled = is_multiplayer_authority()
	input_synchronizer.set_multiplayer_authority(data.id, false)
	if is_multiplayer_authority():
		sync_timer.start()

func _on_sync_timer_timeout() -> void:
	send_data.rpc(global_position, velocity)

@rpc("authority", "call_remote", "unreliable_ordered")
func send_data(pos: Vector2, vel: Vector2) -> void:
	global_position = global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)

###################################################################
####### Nueva implentacion de tiro con bolas con id ###############
###################################################################

const SHOT_RANGE := 48.0

var is_charging_shot := false


func handle_shot_input() -> void:
	var ball := get_my_ball()

	if Input.is_action_just_pressed("shoot"):
		if can_begin_shot(ball):
			is_charging_shot = true
			ball.request_charge_start.rpc()

	if Input.is_action_just_released("shoot") and is_charging_shot:
		is_charging_shot = false

		if ball == null:
			return

		var mouse_position: Vector2 = get_global_mouse_position()
		ball.request_hit.rpc(mouse_position)


func get_my_ball() -> Node2D:
	var target_ball_name := "Ball_" + str(multiplayer.get_unique_id())

	for ball in get_tree().get_nodes_in_group("balls"):
		if ball.name == target_ball_name:
			return ball as Node2D

	return null


func can_begin_shot(ball: Node2D) -> bool:
	if ball == null:
		return false

	if global_position.distance_to(ball.global_position) > SHOT_RANGE:
		return false

	if ball.has_method("is_stopped") and not ball.is_stopped():
		return false

	return true


	
	
#func shoot_my_ball(direction: Vector2, power: float) -> void:
	#var my_id = multiplayer.get_unique_id()
	#
	## Construimos el nombre exacto que le dimos a la pelota en el servidor
	#var target_ball_name = "Ball_" + str(my_id)
	#var balls = get_tree().get_nodes_in_group("balls")
	#
	#for ball in balls:
		#if ball.name == target_ball_name:
			## Pelota encontrada de forma garantizada, enviamos RPC
			#ball.request_hit.rpc(direction, power)
			#return # Terminamos la función
			
	#print("Error: No encontré mi pelota con el nombre: ", target_ball_name)
