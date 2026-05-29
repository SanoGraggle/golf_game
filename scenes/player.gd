# player.gd
extends CharacterBody2D

const SPEED = 150.0

@export var player_color: Color = Color.WHITE # Nueva variable sincronizada
@onready var sprite: Sprite2D = $Sprite2D # Asegúrate de que el nombre coincida con tu nodo Sprite2D
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var camera: Camera2D = $Camera2D

# --- Indicador de pelota fuera de pantalla ---
var ball_indicator_scene: PackedScene = preload("res://scenes/ball_indicator.tscn")
var _indicator_instance: CanvasLayer = null

# --- Minimapa ---
var minimap_scene: PackedScene = preload("res://scenes/minimap.tscn")
var _minimap_instance: CanvasLayer = null

func _process(_delta: float) -> void:
	# Sincronizamos el color visualmente en todos los clientes
	if sprite and sprite.self_modulate != player_color:
		sprite.self_modulate = player_color

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		var direction_x := Input.get_axis("move_left", "move_right")
		var direction_y := Input.get_axis("move_up", "move_down")

		velocity.x = direction_x * SPEED if direction_x else move_toward(velocity.x, 0, SPEED)
		velocity.y = direction_y * SPEED if direction_y else move_toward(velocity.y, 0, SPEED)
		
		handle_shot_input()
		#if Input.is_action_just_pressed("ui_accept"):
			#var shot_direction = velocity.normalized()
			#if shot_direction == Vector2.ZERO:
				#shot_direction = Vector2.UP 
			#shoot_my_ball(shot_direction, 500.0)

	move_and_slide()
	
func setup(data: Statics.PlayerData) -> void:
	name = str(data.id)
	set_multiplayer_authority(data.id, false)
	multiplayer_synchronizer.set_multiplayer_authority(data.id, false)
	# Activar la cámara solo para el jugador local (debe ser después de set_multiplayer_authority)
	camera.enabled = is_multiplayer_authority()
	
	# Si somos el jugador local, crear el indicador de pelota
	if is_multiplayer_authority():
		_setup_ball_indicator()

func _setup_ball_indicator() -> void:
	# Esperamos un poco para que la pelota se haya spawneado
	# (el servidor las crea con 0.5s de delay, agregamos un poco más de margen)
	await get_tree().create_timer(1.0).timeout
	
	var my_ball: RigidBody2D = _find_my_ball()
	if my_ball == null:
		# Reintentar una vez más después de otro segundo
		await get_tree().create_timer(1.0).timeout
		my_ball = _find_my_ball()
	
	if my_ball == null:
		print("BallIndicator: No se encontró la pelota del jugador local")
		return
	
	# Instanciar el indicador
	_indicator_instance = ball_indicator_scene.instantiate()
	add_child(_indicator_instance)
	
	# Configurar el indicador (el script está en el hijo IndicatorControl)
	var indicator_control: Control = _indicator_instance.get_node("IndicatorControl")
	if indicator_control and indicator_control.has_method("setup"):
		indicator_control.setup(my_ball, camera)
		print("BallIndicator: Indicador configurado para pelota ", my_ball.name)
	
	# Instanciar el minimapa
	_minimap_instance = minimap_scene.instantiate()
	add_child(_minimap_instance)
	
	var minimap_control: Control = _minimap_instance.get_node("MinimapControl")
	if minimap_control and minimap_control.has_method("setup"):
		minimap_control.setup(self, my_ball)
		print("Minimap: Configurado para jugador local")

func _find_my_ball() -> RigidBody2D:
	var my_id: int = multiplayer.get_unique_id()
	var target_ball_name: String = "Ball_" + str(my_id)
	var balls: Array[Node] = get_tree().get_nodes_in_group("balls")
	
	for ball: Node in balls:
		if ball.name == target_ball_name:
			return ball as RigidBody2D
	return null

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
#

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
