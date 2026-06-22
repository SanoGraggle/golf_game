# player.gd
extends CharacterBody2D

const BASE_SPEED := 150.0
var current_speed := BASE_SPEED

## Speed boost (monedas)
var _speed_boost_multiplier := 1.0
var _boost_timer: Timer = null

@export var player_color: Color = Color.WHITE # Nueva variable sincronizada
@onready var sprite: Sprite2D = $Sprite2D # Asegúrate de que el nombre coincida con tu nodo Sprite2D
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var camera: Camera2D = $Camera2D

@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer	

# --- Minimapa ---
var minimap_scene: PackedScene = preload("res://scenes/minimap.tscn")
var _minimap_instance: CanvasLayer = null

# --- Indicador de pelota fuera de pantalla ---
var ball_indicator_scene: PackedScene = preload("res://scenes/ball_indicator.tscn")
var _indicator_instance: CanvasLayer = null

# --- Barra de carga de tiro ---
var charge_bar_script: GDScript = preload("res://scenes/charge_bar.gd")
var _charge_bar: Node2D = null

func _process(_delta: float) -> void:
	# Sincronizamos el color visualmente en todos los clientes
	if sprite and sprite.self_modulate != player_color:
		sprite.self_modulate = player_color

func _physics_process(_delta: float) -> void:
	var move_input: Vector2 = input_synchronizer.move_input

	velocity.x = move_input.x * current_speed if move_input.x else move_toward(velocity.x, 0, current_speed)
	velocity.y = move_input.y * current_speed if move_input.y else move_toward(velocity.y, 0, current_speed)

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
		_setup_hud()

func _setup_hud() -> void:
	# Esperamos a que la pelota se haya spawneado (el servidor las crea con delay)
	await get_tree().create_timer(1.0).timeout
	
	var my_ball: Node2D = get_my_ball()
	if my_ball == null:
		# Reintentar una vez más
		await get_tree().create_timer(1.0).timeout
		my_ball = get_my_ball()
	
	if my_ball == null:
		print("HUD: No se encontró la pelota del jugador local")
		return
	
	# Instanciar el minimapa
	_minimap_instance = minimap_scene.instantiate()
	add_child(_minimap_instance)
	
	var minimap_control: Control = _minimap_instance.get_node("MinimapControl")
	if minimap_control and minimap_control.has_method("setup"):
		minimap_control.setup(self, my_ball)
		print("Minimap: Configurado correctamente")
	
	# Instanciar el indicador de pelota fuera de pantalla
	_indicator_instance = ball_indicator_scene.instantiate()
	add_child(_indicator_instance)
	
	var indicator_control: Control = _indicator_instance.get_node("IndicatorControl")
	if indicator_control and indicator_control.has_method("setup"):
		indicator_control.setup(my_ball, camera)
		print("BallIndicator: Configurado correctamente")
	
	# Crear la barra de carga (Node2D hijo del jugador, se mueve con él)
	_charge_bar = Node2D.new()
	_charge_bar.set_script(charge_bar_script)
	add_child(_charge_bar)
	print("ChargeBar: Configurada correctamente")

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
			# Activar la barra de carga visual
			if _charge_bar and _charge_bar.has_method("start_charge"):
				_charge_bar.start_charge()

	if Input.is_action_just_released("shoot") and is_charging_shot:
		is_charging_shot = false
		# Desactivar la barra de carga visual
		if _charge_bar and _charge_bar.has_method("stop_charge"):
			_charge_bar.stop_charge()

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


## Aplica un boost de velocidad temporal (monedas)
func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_boost_multiplier = multiplier
	current_speed = BASE_SPEED * _speed_boost_multiplier

	# Crear o reiniciar el timer del boost
	if _boost_timer != null:
		_boost_timer.stop()
		_boost_timer.queue_free()

	_boost_timer = Timer.new()
	_boost_timer.wait_time = duration
	_boost_timer.one_shot = true
	_boost_timer.timeout.connect(_on_boost_timeout)
	add_child(_boost_timer)
	_boost_timer.start()

	# Efecto visual en todos los clientes
	_show_boost_effect.rpc()

func _on_boost_timeout() -> void:
	_speed_boost_multiplier = 1.0
	current_speed = BASE_SPEED
	if _boost_timer != null:
		_boost_timer.queue_free()
		_boost_timer = null
	_hide_boost_effect.rpc()

@rpc("authority", "call_local", "reliable")
func _show_boost_effect() -> void:
	# Tinte dorado mientras dure el boost
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", Color(1.0, 0.85, 0.0), 0.2)

@rpc("authority", "call_local", "reliable")
func _hide_boost_effect() -> void:
	# Restaurar el color original del jugador
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", player_color, 0.3)
