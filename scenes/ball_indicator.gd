extends Control

## Indicador de pelota fuera de pantalla.
## Muestra una flecha en el borde de la pantalla apuntando hacia la pelota
## cuando ésta sale de la vista de la cámara del jugador.

# Referencia a la pelota que estamos rastreando
var target_ball: Node2D = null
# Referencia a la cámara del jugador
var player_camera: Camera2D = null

# Configuración visual
@export var indicator_size: float = 14.0  ## Tamaño del triángulo indicador
@export var edge_margin: float = 40.0    ## Margen desde el borde de la pantalla
@export var indicator_color: Color = Color.WHITE
@export var show_distance: bool = true   ## Mostrar distancia a la pelota

# Estado interno
var _is_offscreen: bool = false
var _indicator_position: Vector2 = Vector2.ZERO
var _indicator_angle: float = 0.0
var _distance_to_ball: float = 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func setup(ball: Node2D, camera: Camera2D) -> void:
	target_ball = ball
	player_camera = camera
	if ball and ball.get("ball_color") != null:
		indicator_color = ball.ball_color

func _process(_delta: float) -> void:
	if not is_instance_valid(target_ball) or not is_instance_valid(player_camera):
		_is_offscreen = false
		queue_redraw()
		return
	
	if target_ball.get("ball_color") != null:
		indicator_color = target_ball.ball_color
	
	_update_indicator()
	queue_redraw()

func _update_indicator() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var ball_screen_pos: Vector2 = _world_to_screen(target_ball.global_position)
	
	var visible_rect: Rect2 = Rect2(
		Vector2(edge_margin, edge_margin),
		viewport_size - Vector2(edge_margin * 2, edge_margin * 2)
	)
	
	_is_offscreen = not visible_rect.has_point(ball_screen_pos)
	
	if not _is_offscreen:
		return
	
	var screen_center: Vector2 = viewport_size / 2.0
	var direction: Vector2 = (ball_screen_pos - screen_center).normalized()
	
	_indicator_position = _clamp_to_screen_edge(screen_center, direction, viewport_size)
	_indicator_angle = direction.angle()
	_distance_to_ball = player_camera.global_position.distance_to(target_ball.global_position)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform * world_pos

func _clamp_to_screen_edge(center: Vector2, direction: Vector2, viewport_size: Vector2) -> Vector2:
	var margin: float = edge_margin
	var min_pos: Vector2 = Vector2(margin, margin)
	var max_pos: Vector2 = viewport_size - Vector2(margin, margin)
	
	var t_values: Array[float] = []
	
	if direction.x != 0:
		var t1: float = (min_pos.x - center.x) / direction.x
		var t2: float = (max_pos.x - center.x) / direction.x
		if t1 > 0:
			t_values.append(t1)
		if t2 > 0:
			t_values.append(t2)
	
	if direction.y != 0:
		var t3: float = (min_pos.y - center.y) / direction.y
		var t4: float = (max_pos.y - center.y) / direction.y
		if t3 > 0:
			t_values.append(t3)
		if t4 > 0:
			t_values.append(t4)
	
	var best_t: float = INF
	for t: float in t_values:
		var point: Vector2 = center + direction * t
		if point.x >= min_pos.x - 1 and point.x <= max_pos.x + 1 \
			and point.y >= min_pos.y - 1 and point.y <= max_pos.y + 1:
			if t < best_t:
				best_t = t
	
	if best_t == INF:
		best_t = 1.0
	
	var result: Vector2 = center + direction * best_t
	result.x = clampf(result.x, min_pos.x, max_pos.x)
	result.y = clampf(result.y, min_pos.y, max_pos.y)
	
	return result

func _draw() -> void:
	if not _is_offscreen:
		return
	
	var s: float = indicator_size
	
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(s, 0),
		Vector2(-s * 0.6, -s * 0.7),
		Vector2(-s * 0.6, s * 0.7),
	])
	
	var rotated_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		rotated_points.append(point.rotated(_indicator_angle) + _indicator_position)
	
	var fill_color: Color = indicator_color
	fill_color.a = 0.9
	var outline_color: Color = Color.WHITE
	outline_color.a = 0.95
	
	# Sombra
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in rotated_points:
		shadow_points.append(point + Vector2(2, 2))
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.3))
	
	# Relleno
	draw_colored_polygon(rotated_points, fill_color)
	
	# Borde
	var border_points: PackedVector2Array = rotated_points
	border_points.append(rotated_points[0])
	draw_polyline(border_points, outline_color, 2.0, true)
	
	# Círculo pulsante
	var pulse: float = (sin(Time.get_ticks_msec() / 300.0) + 1.0) / 2.0
	var pulse_color: Color = indicator_color
	pulse_color.a = 0.15 + pulse * 0.15
	draw_circle(_indicator_position, s * 1.5 + pulse * 4.0, pulse_color)
	
	# Texto de distancia
	if show_distance:
		var dist_text: String = str(int(_distance_to_ball)) + "px"
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 12
		var text_offset: Vector2 = Vector2(0, indicator_size + 18)
		
		var viewport_size: Vector2 = get_viewport_rect().size
		if _indicator_position.y > viewport_size.y - edge_margin - 10:
			text_offset.y = -(indicator_size + 8)
		
		var text_pos: Vector2 = _indicator_position + text_offset
		var text_size: Vector2 = font.get_string_size(dist_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		text_pos.x -= text_size.x / 2.0
		
		var bg_rect: Rect2 = Rect2(text_pos - Vector2(4, font_size), text_size + Vector2(8, font_size * 0.4))
		draw_rect(bg_rect, Color(0, 0, 0, 0.5), true)
		draw_string(font, text_pos, dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
