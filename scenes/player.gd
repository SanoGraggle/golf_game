# player.gd
extends CharacterBody2D

#### Sounds 
@onready var sfx_player: AudioStreamPlayer2D = $SFX_Player

@onready var weak_shot_stream: AudioStream = load("res://assets/Sounds/Weak_Golf_Shot.wav")
@onready var medium_shot_stream: AudioStream = load("res://assets/Sounds/Medium_Golf_Shot.wav")
@onready var strong_shot_stream: AudioStream = load("res://assets/Sounds/Strong_Golf_Shot.wav")

@onready var speed_power_up_stream: AudioStream = load("res://assets/Sounds/Speed_Power_up.ogg")
@onready var freeze_power_up_stream: AudioStream = load("res://assets/Sounds/Freeze_Power_up.wav")
@onready var oof_stream: AudioStream = load("res://assets/Sounds/Oof.mp3")


const BASE_SPEED := 150.0
var current_speed := BASE_SPEED
var is_stunned: bool = false

## Speed boost (monedas)
var _speed_boost_multiplier := 1.0
var _boost_timer: Timer = null

## Freeze power-up (moneda de hielo)
var is_frozen := false
var _freeze_timer: Timer = null
var _ice_sprite: Sprite2D = null

## Contadores de tiempo restante de power-ups (local, cada peer lo decrementa)
var _boost_time_remaining := 0.0
var _freeze_time_remaining := 0.0
var _boost_countdown_label: Label = null
var _freeze_countdown_label: Label = null

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

func _ready() -> void:
	add_to_group("players") # Vital para poder buscar a los rivales
	
	var ball_hit_box: Area2D = $BallHitBox
	if ball_hit_box != null:
		ball_hit_box.body_entered.connect(_on_ball_hit_box_body_entered)
	
func _process(delta: float) -> void:
	# Sincronizamos el color visualmente en todos los clientes
	# No sobreescribir si hay un efecto visual activo (freeze o boost)
	if sprite and sprite.self_modulate != player_color and not is_frozen and _speed_boost_multiplier <= 1.0:
		sprite.self_modulate = player_color

	# Actualizar contadores de power-ups
	if _boost_time_remaining > 0.0:
		_boost_time_remaining -= delta
		if _boost_time_remaining < 0.0:
			_boost_time_remaining = 0.0
		_update_countdown_label(_boost_countdown_label, _boost_time_remaining)

	if _freeze_time_remaining > 0.0:
		_freeze_time_remaining -= delta
		if _freeze_time_remaining < 0.0:
			_freeze_time_remaining = 0.0
		_update_countdown_label(_freeze_countdown_label, _freeze_time_remaining)

func _physics_process(delta: float) -> void:
	if is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_stunned:
		var friction = 1200.0 
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	else:
		var move_input: Vector2 = input_synchronizer.move_input

		velocity.x = move_input.x * current_speed if move_input.x else move_toward(velocity.x, 0, current_speed)
		velocity.y = move_input.y * current_speed if move_input.y else move_toward(velocity.y, 0, current_speed)

	move_and_slide()

	if is_multiplayer_authority() and not is_stunned:
		handle_shot_input(delta)
	
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
var is_shot_cancelled := false
var _swing_charge_started_msec := -1
var _shot_cooldown := 0.0
var _current_charge_time := 0.0

func handle_shot_input(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta
		return

	var ball := get_my_ball()
	var can_hit_ball := false
	if ball != null and global_position.distance_to(ball.global_position) <= SHOT_RANGE:
		if ball.has_method("is_stopped") and ball.is_stopped():
			can_hit_ball = true

	if Input.is_action_just_pressed("shoot"):
		is_charging_shot = true
		_current_charge_time = 0.0
		request_swing_charge_start.rpc()
		if can_hit_ball:
			ball.request_charge_start.rpc()
		
		# Activar la barra de carga visual
		if _charge_bar and _charge_bar.has_method("start_charge"):
			_charge_bar.start_charge()

	if is_charging_shot:
		_current_charge_time += delta
		if _current_charge_time >= 3.0:
			is_shot_cancelled = true
			is_charging_shot = false
			_shot_cooldown = 1.0 # 1 second cooldown
			if _charge_bar and _charge_bar.has_method("stop_charge"):
				_charge_bar.stop_charge()
			request_swing_charge_cancel.rpc()
			if can_hit_ball and ball.has_method("request_charge_cancel"):
				ball.request_charge_cancel.rpc()
			return

	if Input.is_action_just_released("shoot") and is_charging_shot:
		is_charging_shot = false
		# Desactivar la barra de carga visual
		if _charge_bar and _charge_bar.has_method("stop_charge"):
			_charge_bar.stop_charge()

		var mouse_position: Vector2 = get_global_mouse_position()
		request_swing_hit.rpc(mouse_position)
		
		if can_hit_ball:
			ball.request_hit.rpc(mouse_position)


func get_my_ball() -> Node2D:
	var target_ball_name := "Ball_" + str(multiplayer.get_unique_id())

	for b in get_tree().get_nodes_in_group("balls"):
		if b.name == target_ball_name:
			return b as Node2D

	return null

@rpc("any_peer", "call_local", "reliable")
func request_swing_charge_start() -> void:
	if not multiplayer.is_server():
		return
	_swing_charge_started_msec = Time.get_ticks_msec()

@rpc("any_peer", "call_local", "reliable")
func request_swing_charge_cancel() -> void:
	if not multiplayer.is_server():
		return
	_swing_charge_started_msec = -1

@rpc("any_peer", "call_local", "reliable")
func request_swing_hit(mouse_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
		
	if _swing_charge_started_msec < 0:
		return
		
	var charge_seconds: float = float(Time.get_ticks_msec() - _swing_charge_started_msec) / 1000.0
	_swing_charge_started_msec = -1
	
	if charge_seconds < 0.0:
		charge_seconds = 0.0
	elif charge_seconds > 1.25: # MAX_CHARGE_TIME from ball.gd
		charge_seconds = 1.25
		
	var charge_ratio: float = charge_seconds / 1.25
	
	var stun_duration = 0.5 + (1.5 * charge_ratio) # 0.5s to 2.0s
	var knockback_power = 200.0 + (600.0 * charge_ratio)
	
	var swing_direction = (mouse_position - global_position).normalized()
	if swing_direction.length() == 0:
		return
		
	for other_player in get_tree().get_nodes_in_group("players"):
		if other_player == self:
			continue
			
		var distance = global_position.distance_to(other_player.global_position)
		if distance <= SHOT_RANGE:
			var to_other = (other_player.global_position - global_position).normalized()
			# Si el jugador está dentro de un cono de 180 grados en la dirección del golpe
			if swing_direction.dot(to_other) > 0.0:
				var knockback_vel = swing_direction * knockback_power
				other_player.apply_knockback_and_stun.rpc(knockback_vel, stun_duration)
				
	for b in get_tree().get_nodes_in_group("balls"):
		var ball := b as Node2D
		if ball.name == "Ball_" + str(name):
			continue # Mi propia bola es golpeada por la lógica normal
			
		var distance = global_position.distance_to(ball.global_position)
		if distance <= SHOT_RANGE:
			var to_ball = (ball.global_position - global_position).normalized()
			# Si la bola está dentro de un cono de 180 grados en la dirección del golpe
			if swing_direction.dot(to_ball) > 0.0:
				var ball_power = 120.0 + ((700.0 - 120.0) * charge_ratio) # MIN_IMPULSE to MAX_IMPULSE
				ball_power *= 0.3 # El golpe a otra bola es un 30% del original
				if ball.has_method("apply_opponent_hit"):
					ball.apply_opponent_hit.rpc(swing_direction * ball_power)

@rpc("any_peer", "call_local", "reliable")
func apply_knockback_and_stun(knockback_velocity: Vector2, stun_duration: float) -> void:
	is_stunned = true
	velocity = knockback_velocity
	
	play_oof_sound.rpc()
	
	if is_charging_shot:
		is_shot_cancelled = true
		is_charging_shot = false
		if _charge_bar and _charge_bar.has_method("stop_charge"):
			_charge_bar.stop_charge()
			
	# Restaurar el estado de aturdimiento después del tiempo correspondiente
	var timer = get_tree().create_timer(stun_duration)
	timer.timeout.connect(func(): is_stunned = false)


func _on_ball_hit_box_body_entered(body: Node2D) -> void:
	if not body.is_in_group("balls"):
		return
	
	var ball := body as RigidBody2D
	if ball == null:
		return
	
	# Only the server applies the hit so all clients stay in sync.
	if not multiplayer.is_server():
		return
	
	# Ignore very slow balls.
	var ball_speed: float = ball.linear_velocity.length()
	if ball_speed < 50.0:
		return
	
	# Avoid hitting the owner's own ball.
	if ball.name == "Ball_" + str(name):
		return
	
	var knockback_direction: Vector2 = (global_position - ball.global_position).normalized()
	if knockback_direction.length() == 0:
		knockback_direction = Vector2.RIGHT
	
	var knockback_power: float = clampf(ball_speed * 0.5, 100.0, 400.0)
	var stun_duration: float = 0.5
	apply_knockback_and_stun.rpc(knockback_direction * knockback_power, stun_duration)


@rpc("authority", "call_local", "reliable")
func play_oof_sound() -> void:
	if sfx_player != null and oof_stream != null:
		sfx_player.stream = oof_stream
		sfx_player.play()


## Aplica un boost de velocidad temporal (monedas)
## Llamado solo en el servidor desde coin.gd
func apply_speed_boost(multiplier: float, duration: float) -> void:
	# Crear o reiniciar el timer del boost (solo en el servidor)
	if _boost_timer != null:
		_boost_timer.stop()
		_boost_timer.queue_free()

	_boost_timer = Timer.new()
	_boost_timer.wait_time = duration
	_boost_timer.one_shot = true
	_boost_timer.timeout.connect(_on_boost_timeout)
	add_child(_boost_timer)
	_boost_timer.start()

	# Sincronizar el estado de velocidad a TODOS los peers
	_sync_boost_start.rpc(multiplier, duration)

func _on_boost_timeout() -> void:
	if _boost_timer != null:
		_boost_timer.queue_free()
		_boost_timer = null
	# Sincronizar el fin del boost a TODOS los peers
	_sync_boost_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_boost_start(multiplier: float, duration: float) -> void:
	_speed_boost_multiplier = multiplier
	current_speed = BASE_SPEED * _speed_boost_multiplier
	if sfx_player != null and speed_power_up_stream != null:
		sfx_player.stream = speed_power_up_stream
		sfx_player.play()
	_boost_time_remaining = duration
	# Efecto visual: tinte dorado
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", Color(1.0, 0.85, 0.0), 0.2)
	# Crear label de countdown (solo en este jugador)
	if is_multiplayer_authority():
		_remove_countdown_label(_boost_countdown_label)
		_boost_countdown_label = _create_countdown_label(Color(1.0, 0.85, 0.0), Vector2(0, -28))

@rpc("any_peer", "call_local", "reliable")
func _sync_boost_end() -> void:
	_speed_boost_multiplier = 1.0
	current_speed = BASE_SPEED
	_boost_time_remaining = 0.0
	# Restaurar color original
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", player_color, 0.3)
	# Eliminar label de countdown
	_remove_countdown_label(_boost_countdown_label)
	_boost_countdown_label = null

## ============================================================
## Freeze power-up (moneda de hielo) — congela al rival
## ============================================================

## Aplica congelamiento al jugador (solo el servidor llama esto)
func apply_freeze(duration: float) -> void:
	# Crear o reiniciar el timer del freeze (solo en el servidor)
	if _freeze_timer != null:
		_freeze_timer.stop()
		_freeze_timer.queue_free()

	_freeze_timer = Timer.new()
	_freeze_timer.wait_time = duration
	_freeze_timer.one_shot = true
	_freeze_timer.timeout.connect(_on_freeze_timeout)
	add_child(_freeze_timer)
	_freeze_timer.start()

	# Sincronizar el estado de freeze a TODOS los peers
	_sync_freeze_start.rpc(duration)

func _on_freeze_timeout() -> void:
	if _freeze_timer != null:
		_freeze_timer.queue_free()
		_freeze_timer = null
	# Sincronizar el fin del freeze a TODOS los peers
	_sync_freeze_end.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_freeze_start(duration: float) -> void:
	is_frozen = true
	if sfx_player != null and freeze_power_up_stream != null:
		sfx_player.stream = freeze_power_up_stream
		sfx_player.play()
	velocity = Vector2.ZERO
	_freeze_time_remaining = duration
	# Crear label de countdown (solo en este jugador)
	if is_multiplayer_authority():
		_remove_countdown_label(_freeze_countdown_label)
		_freeze_countdown_label = _create_countdown_label(Color(0.5, 0.85, 1.0), Vector2(0, -28))

	# Tinte celeste mientras dure el freeze
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", Color(0.5, 0.85, 1.0), 0.15)

	# Crear sprite de cubo de hielo encima del jugador
	if _ice_sprite == null:
		_ice_sprite = Sprite2D.new()
		_ice_sprite.name = "IceCubeOverlay"
		# Dibujar un cubo de hielo celeste proceduralmente
		var img := Image.create(20, 24, false, Image.FORMAT_RGBA8)
		var ice_color := Color(0.55, 0.88, 1.0, 0.7)
		var ice_border := Color(0.3, 0.7, 0.95, 0.9)
		var ice_highlight := Color(0.85, 0.95, 1.0, 0.9)

		# Rellenar el cubo
		for y in range(2, 22):
			for x in range(2, 18):
				img.set_pixel(x, y, ice_color)

		# Bordes del cubo
		for x in range(1, 19):
			img.set_pixel(x, 1, ice_border)
			img.set_pixel(x, 22, ice_border)
		for y in range(1, 23):
			img.set_pixel(1, y, ice_border)
			img.set_pixel(18, y, ice_border)

		# Esquinas redondeadas
		img.set_pixel(1, 1, Color.TRANSPARENT)
		img.set_pixel(18, 1, Color.TRANSPARENT)
		img.set_pixel(1, 22, Color.TRANSPARENT)
		img.set_pixel(18, 22, Color.TRANSPARENT)

		# Brillo/highlight en la esquina superior izquierda
		for y in range(3, 8):
			for x in range(3, 7):
				img.set_pixel(x, y, ice_highlight)

		# Línea diagonal de brillo
		for i in range(5):
			if 3 + i < 18 and 3 + i < 22:
				img.set_pixel(3 + i, 3 + i, ice_highlight)

		var tex := ImageTexture.create_from_image(img)
		_ice_sprite.texture = tex
		_ice_sprite.position = Vector2(0, -8)
		_ice_sprite.z_index = 5
		add_child(_ice_sprite)

	# Animación de aparición
	_ice_sprite.scale = Vector2.ZERO
	_ice_sprite.modulate = Color(1, 1, 1, 1)
	var appear_tween: Tween = create_tween()
	appear_tween.tween_property(_ice_sprite, "scale", Vector2(1.2, 1.2), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

@rpc("any_peer", "call_local", "reliable")
func _sync_freeze_end() -> void:
	is_frozen = false
	_freeze_time_remaining = 0.0

	# Restaurar color original
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "self_modulate", player_color, 0.3)
	# Eliminar label de countdown
	_remove_countdown_label(_freeze_countdown_label)
	_freeze_countdown_label = null

	# Animación de desaparición del cubo de hielo
	if _ice_sprite != null:
		var disappear_tween: Tween = create_tween()
		disappear_tween.set_parallel(true)
		disappear_tween.tween_property(_ice_sprite, "scale", Vector2(2.0, 2.0), 0.3).set_ease(Tween.EASE_IN)
		disappear_tween.tween_property(_ice_sprite, "modulate:a", 0.0, 0.3)
		disappear_tween.set_parallel(false)
		disappear_tween.tween_callback(_remove_ice_sprite)

@rpc("authority", "call_local", "reliable")
func play_shot_sound(charge_ratio: float) -> void:
	if sfx_player == null:
		return
	if charge_ratio < 0.33:
		sfx_player.stream = weak_shot_stream
	elif charge_ratio < 0.66:
		sfx_player.stream = medium_shot_stream
	else:
		sfx_player.stream = strong_shot_stream
	if sfx_player.stream != null:
		sfx_player.play()

func _remove_ice_sprite() -> void:
	if _ice_sprite != null:
		_ice_sprite.queue_free()
		_ice_sprite = null

## ============================================================
## Countdown labels para power-ups
## ============================================================

func _create_countdown_label(color: Color, offset: Vector2) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = offset - Vector2(30, 0)
	label.size = Vector2(60, 20)
	label.z_index = 10

	# Estilo del texto
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	# Fondo con panel estilizado
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.35)
	style.border_color = Color(color.r, color.g, color.b, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = offset - Vector2(22, 0)
	panel.size = Vector2(44, 16)
	panel.z_index = 9
	panel.name = "CountdownPanel"

	add_child(panel)
	add_child(label)

	# Guardar referencia al panel en el label para limpiar después
	label.set_meta("panel_ref", panel)
	return label

func _update_countdown_label(label: Label, time_remaining: float) -> void:
	if label == null:
		return
	label.text = "%.1fs" % time_remaining

func _remove_countdown_label(label: Label) -> void:
	if label == null:
		return
	# Eliminar el panel asociado
	if label.has_meta("panel_ref"):
		var panel: Node = label.get_meta("panel_ref")
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	label.queue_free()
