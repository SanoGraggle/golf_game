extends RigidBody2D

@export var ball_color: Color = Color.WHITE
@onready var sprite: Sprite2D = $Sprite2D


####### unique id para cada bola########
@export var owner_peer_id := 0

const SHOT_RANGE := 48.0
const MIN_IMPULSE := 120.0
const MAX_IMPULSE := 700.0
const MAX_CHARGE_TIME := 1.25
const STOPPED_SPEED := 10.0
const STOP_SNAP_SPEED := 18.0
const STOP_SNAP_DELAY := 0.25
const SAND_DAMP := 5.0              ## linear_damp cuando está en arena (más alto = más lento)

var charge_started_msec := -1
var slow_time := 0.0
var _agua_layer: TileMapLayer = null
var _default_linear_damp: float = 0.0  ## Se guarda el linear_damp original del .tscn

func get_owner_id() -> int:
	if owner_peer_id != 0:
		return owner_peer_id
	return name.replace("Ball_", "").to_int()
	
#######################################
# Nueva variable para recordar dónde estaba en el fotograma anterior
var last_position: Vector2

func _ready() -> void:
	add_to_group("balls")
	gravity_scale = 0
	
	# Guardamos la posición inicial para evitar saltos
	last_position = position
	# Guardamos el linear_damp original para restaurarlo cuando salga de la arena
	_default_linear_damp = linear_damp
	
	if not multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true
	if owner_peer_id == 0:
		owner_peer_id = name.replace("Ball_", "").to_int()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if freeze:
		return

	# Detección de arena: buscar la capa AGUA de forma lazy
	if _agua_layer == null:
		var root := get_tree().current_scene
		if root:
			_agua_layer = root.find_child("AGUA", true, false) as TileMapLayer

	# Ajustar linear_damp según el terreno (arena = más fricción)
	if _agua_layer != null:
		var tile_coords := _agua_layer.local_to_map(_agua_layer.to_local(global_position))
		if _agua_layer.get_cell_source_id(tile_coords) >= 0:
			# La bola está sobre arena, aumentar el damping
			linear_damp = SAND_DAMP
		else:
			# Terreno normal, restaurar damping original
			linear_damp = _default_linear_damp

	var speed: float = linear_velocity.length()

	if speed <= STOP_SNAP_SPEED:
		slow_time += delta
	else:
		slow_time = 0.0

	if slow_time >= STOP_SNAP_DELAY:
		stop_ball()
		
func stop_ball() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	freeze = true
	slow_time = 0.0
	
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

func is_stopped() -> bool:
	return linear_velocity.length() <= STOPPED_SPEED


func get_owner_player() -> Node2D:
	return get_tree().root.find_child(str(get_owner_id()), true, false) as Node2D


func can_server_accept_shot(sender_id: int) -> bool:
	if sender_id != get_owner_id():
		return false

	if not is_stopped():
		return false

	var owner_player := get_owner_player()
	if owner_player == null:
		return false

	return owner_player.global_position.distance_to(global_position) <= SHOT_RANGE


@rpc("any_peer", "call_local", "reliable")
func request_charge_start() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if not multiplayer.is_server():
		return

	if not can_server_accept_shot(sender_id):
		return

	charge_started_msec = Time.get_ticks_msec()


@rpc("any_peer", "call_local", "reliable")
func request_hit(mouse_position: Vector2) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if not multiplayer.is_server():
		return

	if charge_started_msec < 0:
		return

	var impulse_direction: Vector2 = mouse_position - global_position

	if impulse_direction.length() <= 0.001:
		charge_started_msec = -1
		return

	if not can_server_accept_shot(sender_id):
		charge_started_msec = -1
		return
	var charge_seconds: float = float(Time.get_ticks_msec() - charge_started_msec) / 1000.0

	if charge_seconds < 0.0:
		charge_seconds = 0.0
	elif charge_seconds > MAX_CHARGE_TIME:
		charge_seconds = MAX_CHARGE_TIME

	charge_started_msec = -1

	var charge_ratio: float = charge_seconds / MAX_CHARGE_TIME
	var impulse_power: float = MIN_IMPULSE + ((MAX_IMPULSE - MIN_IMPULSE) * charge_ratio)
	
	var owner_player := get_owner_player()
	if owner_player != null and owner_player.has_method("play_shot_sound"):
		owner_player.play_shot_sound.rpc(charge_ratio)

	freeze = false
	sleeping = false
	slow_time = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	apply_central_impulse(impulse_direction.normalized() * impulse_power)
