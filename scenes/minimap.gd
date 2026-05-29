extends Control

## Minimapa para el jugador local.
## Muestra: jugador local (chevron), jugadores rivales (diamante) y pelotas (círculo con cruz).
## Mucho más zoom y con iconos grandes y descriptivos para que se distingan bien.

# Referencias
var local_player: CharacterBody2D = null
var local_ball: RigidBody2D = null

# Configuración del minimapa
@export var map_size: Vector2 = Vector2(160, 160)       ## Tamaño del minimapa en píxeles
@export var map_margin: Vector2 = Vector2(16, 16)       ## Margen desde la esquina
@export var world_range: float = 400.0                   ## Radio del mundo visible (más bajo = más zoom)
@export var bg_color: Color = Color(0.05, 0.05, 0.1, 0.8)  ## Fondo
@export var border_color: Color = Color(0.4, 0.45, 0.6, 0.9)  ## Borde

# Tamaños de iconos (mucho más grandes)
@export var local_icon_size: float = 10.0    ## Tamaño del icono del jugador local
@export var rival_icon_size: float = 8.0     ## Tamaño del icono de rivales
@export var ball_icon_size: float = 6.0      ## Tamaño del icono de pelotas

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_update_position()

func setup(player: CharacterBody2D, ball: RigidBody2D) -> void:
	local_player = player
	local_ball = ball

func _update_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2(
		viewport_size.x - map_size.x - map_margin.x,
		viewport_size.y - map_size.y - map_margin.y
	)
	custom_minimum_size = map_size
	size = map_size

func _process(_delta: float) -> void:
	if not is_instance_valid(local_player):
		return
	_update_position()
	queue_redraw()

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	## Convierte una posición del mundo a coordenadas del minimapa,
	## centrado en el jugador local.
	if not is_instance_valid(local_player):
		return map_size / 2.0
	
	var relative: Vector2 = world_pos - local_player.global_position
	var normalized: Vector2 = relative / world_range
	var minimap_pos: Vector2 = (normalized + Vector2.ONE) * 0.5 * map_size
	minimap_pos.x = clampf(minimap_pos.x, 2, map_size.x - 2)
	minimap_pos.y = clampf(minimap_pos.y, 2, map_size.y - 2)
	return minimap_pos

func _is_in_range(world_pos: Vector2) -> bool:
	## Verifica si una posición del mundo está dentro del rango visible del minimapa
	if not is_instance_valid(local_player):
		return false
	var relative: Vector2 = world_pos - local_player.global_position
	return abs(relative.x) <= world_range and abs(relative.y) <= world_range

func _draw() -> void:
	if not is_instance_valid(local_player):
		return
	
	# --- Fondo con bordes redondeados ---
	var bg_rect: Rect2 = Rect2(Vector2.ZERO, map_size)
	draw_rect(bg_rect, bg_color, true)
	draw_rect(bg_rect, border_color, false, 2.0)
	
	# Cruz central sutil
	var grid_color: Color = Color(1, 1, 1, 0.08)
	draw_line(Vector2(map_size.x / 2, 0), Vector2(map_size.x / 2, map_size.y), grid_color, 1.0)
	draw_line(Vector2(0, map_size.y / 2), Vector2(map_size.x, map_size.y / 2), grid_color, 1.0)
	
	# Rango de alcance visual (círculo sutil)
	var range_color: Color = Color(1, 1, 1, 0.04)
	draw_arc(map_size / 2.0, map_size.x * 0.4, 0, TAU, 32, range_color, 1.0)
	
	# --- Recopilar info de pelotas para vincular con jugadores ---
	var balls: Array[Node] = get_tree().get_nodes_in_group("balls")
	var ball_map: Dictionary = {}  # peer_id -> ball node
	for ball: Node in balls:
		if ball is RigidBody2D:
			var ball_name: String = ball.name
			if ball_name.begins_with("Ball_"):
				var peer_id: String = ball_name.replace("Ball_", "")
				ball_map[peer_id] = ball
	
	# --- Dibujar líneas de conexión jugador->pelota (debajo de todo) ---
	var players_node: Node = _find_players_container()
	if players_node:
		for child: Node in players_node.get_children():
			if child is CharacterBody2D:
				var player_minimap_pos: Vector2
				if child == local_player:
					player_minimap_pos = map_size / 2.0
				else:
					player_minimap_pos = _world_to_minimap(child.global_position)
				
				# Buscar la pelota de este jugador
				var player_id: String = str(child.name)
				if ball_map.has(player_id):
					var pball: RigidBody2D = ball_map[player_id]
					var ball_minimap_pos: Vector2 = _world_to_minimap(pball.global_position)
					var line_color: Color = Color(1, 1, 1, 0.12)
					if child.get("player_color") != null:
						line_color = child.player_color
						line_color.a = 0.2
					draw_dashed_line(player_minimap_pos, ball_minimap_pos, line_color, 1.0, 4.0)
	
	# --- Dibujar jugadores rivales (diamante) ---
	if players_node:
		for child: Node in players_node.get_children():
			if child is CharacterBody2D and child != local_player:
				var rival_pos: Vector2 = _world_to_minimap(child.global_position)
				var rival_color: Color = Color.GRAY
				if child.get("player_color") != null:
					rival_color = child.player_color
				_draw_diamond(rival_pos, rival_icon_size, rival_color)
	
	# --- Dibujar todas las pelotas (círculo con cruz) ---
	for ball: Node in balls:
		if ball is RigidBody2D:
			var ball_pos: Vector2 = _world_to_minimap(ball.global_position)
			var b_color: Color = Color.WHITE
			if ball.get("ball_color") != null:
				b_color = ball.ball_color
			_draw_ball_icon(ball_pos, ball_icon_size, b_color)
	
	# --- Dibujar jugador local (chevron/flecha, siempre centrado y encima) ---
	var local_pos: Vector2 = map_size / 2.0
	var local_color: Color = local_player.player_color if local_player.player_color else Color.WHITE
	_draw_player_chevron(local_pos, local_icon_size, local_color)
	
	# --- Leyenda ---
	_draw_legend()


# ============================================================
# ICONOS DESCRIPTIVOS
# ============================================================

func _draw_player_chevron(pos: Vector2, s: float, color: Color) -> void:
	## Jugador local: flecha/chevron con dirección de movimiento
	var direction: Vector2 = Vector2.ZERO
	if is_instance_valid(local_player):
		direction = local_player.velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	
	var angle: float = direction.angle() - PI / 2.0
	
	# Triángulo apuntando en la dirección de movimiento
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s),            # Punta
		Vector2(-s * 0.7, s * 0.6),  # Izquierda
		Vector2(0, s * 0.2),        # Muesca central
		Vector2(s * 0.7, s * 0.6),   # Derecha
	])
	
	# Rotar y trasladar
	var transformed: PackedVector2Array = PackedVector2Array()
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		transformed.append(p.rotated(angle) + pos)
		shadow_points.append(p.rotated(angle) + pos + Vector2(1.5, 1.5))
	
	# Sombra
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.5))
	# Relleno
	draw_colored_polygon(transformed, color)
	# Borde
	var border_pts: PackedVector2Array = transformed
	border_pts.append(transformed[0])
	draw_polyline(border_pts, Color.WHITE, 1.5, true)
	
	# Anillo pulsante
	var pulse: float = (sin(Time.get_ticks_msec() / 400.0) + 1.0) / 2.0
	var ring_color: Color = color
	ring_color.a = 0.2 + pulse * 0.25
	draw_arc(pos, s + 4.0 + pulse * 3.0, 0, TAU, 20, ring_color, 1.5)

func _draw_diamond(pos: Vector2, s: float, color: Color) -> void:
	## Jugador rival: diamante/rombo
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s),     # Arriba
		Vector2(s, 0),      # Derecha
		Vector2(0, s),      # Abajo
		Vector2(-s, 0),     # Izquierda
	])
	
	var transformed: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		transformed.append(p + pos)
	
	# Sombra
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in transformed:
		shadow.append(p + Vector2(1, 1))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	
	# Relleno
	draw_colored_polygon(transformed, color)
	
	# Borde
	var border_pts: PackedVector2Array = transformed
	border_pts.append(transformed[0])
	var border_c: Color = color
	border_c = border_c.lightened(0.3)
	border_c.a = 0.9
	draw_polyline(border_pts, border_c, 1.5, true)

func _draw_ball_icon(pos: Vector2, s: float, color: Color) -> void:
	## Pelota: círculo con cruz interior (como una pelota de golf)
	# Sombra
	draw_circle(pos + Vector2(1, 1), s + 1.0, Color(0, 0, 0, 0.4))
	# Círculo exterior
	draw_circle(pos, s + 1.0, Color.WHITE)
	# Relleno con color
	draw_circle(pos, s, color)
	# Cruz interior para distinguirla
	var cross_color: Color = Color(1, 1, 1, 0.5)
	var cs: float = s * 0.6
	draw_line(pos + Vector2(-cs, 0), pos + Vector2(cs, 0), cross_color, 1.0)
	draw_line(pos + Vector2(0, -cs), pos + Vector2(0, cs), cross_color, 1.0)

func _draw_legend() -> void:
	## Dibuja una leyenda pequeña arriba del minimapa
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 9
	var label_alpha: float = 0.5
	
	# Icono de TÚ (circulito + texto)
	var y_offset: float = map_size.y - 12
	var local_color: Color = Color.WHITE
	if is_instance_valid(local_player) and local_player.player_color:
		local_color = local_player.player_color
	
	# Punto + "TÚ"
	draw_circle(Vector2(8, y_offset), 3, local_color)
	draw_string(font, Vector2(14, y_offset + 3), "Tú", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, label_alpha))
	
	# Diamante + "Rival"
	var rx: float = 46
	var diamond_mini: PackedVector2Array = PackedVector2Array([
		Vector2(rx, y_offset - 3), Vector2(rx + 3, y_offset),
		Vector2(rx, y_offset + 3), Vector2(rx - 3, y_offset),
	])
	draw_colored_polygon(diamond_mini, Color.GRAY)
	draw_string(font, Vector2(rx + 6, y_offset + 3), "Rival", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, label_alpha))
	
	# Circulo + cruz + "Bola"
	var bx: float = 96
	draw_circle(Vector2(bx, y_offset), 3, Color.WHITE)
	draw_line(Vector2(bx - 1.5, y_offset), Vector2(bx + 1.5, y_offset), Color(1, 1, 1, 0.5), 1.0)
	draw_line(Vector2(bx, y_offset - 1.5), Vector2(bx, y_offset + 1.5), Color(1, 1, 1, 0.5), 1.0)
	draw_string(font, Vector2(bx + 6, y_offset + 3), "Bola", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, label_alpha))


# ============================================================
# UTILIDADES
# ============================================================

func _find_players_container() -> Node:
	## Busca el nodo "Players" en el árbol del mundo
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	var players: Node = root.find_child("Players", true, false)
	return players
