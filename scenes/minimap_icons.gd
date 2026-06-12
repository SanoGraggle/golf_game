extends Control

## Capa de iconos del minimapa.
## Se dibuja ENCIMA del SubViewport que renderiza el mapa real.
## Dibuja: jugador local (chevron), rivales (diamante), pelotas (círculo con cruz).

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	var panel: Control = get_parent()
	if panel == null:
		return
	if not panel.has_method("world_to_minimap"):
		return
	if not is_instance_valid(panel.local_player):
		return
	
	var map_size: Vector2 = panel.map_size
	var local_player: CharacterBody2D = panel.local_player
	
	# --- Borde del minimapa (encima del viewport) ---
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.3, 0.35, 0.5, 0.9), false, 2.0)
	
	# --- Líneas de conexión jugador→pelota (debajo de los iconos) ---
	var balls: Array[Node] = get_tree().get_nodes_in_group("balls")
	var ball_map: Dictionary = {}
	for ball: Node in balls:
		if ball is RigidBody2D:
			var bname: String = ball.name
			if bname.begins_with("Ball_"):
				ball_map[bname.replace("Ball_", "")] = ball
	
	var players_node: Node = _find_players_container()
	if players_node:
		for child: Node in players_node.get_children():
			if child is CharacterBody2D:
				var p_pos: Vector2
				if child == local_player:
					p_pos = map_size / 2.0
				else:
					p_pos = panel.world_to_minimap(child.global_position)
				var pid: String = str(child.name)
				if ball_map.has(pid):
					var b_pos: Vector2 = panel.world_to_minimap(ball_map[pid].global_position)
					var lc: Color = Color.GRAY
					if child.get("player_color") != null:
						lc = child.player_color
					lc.a = 0.35
					draw_dashed_line(p_pos, b_pos, lc, 1.5, 4.0)
	
	# --- Jugadores rivales (diamante) ---
	if players_node:
		for child: Node in players_node.get_children():
			if child is CharacterBody2D and child != local_player:
				var pos: Vector2 = panel.world_to_minimap(child.global_position)
				var color: Color = Color.GRAY
				if child.get("player_color") != null:
					color = child.player_color
				_draw_diamond(pos, 8.0, color)
	
	# --- Todas las pelotas (círculo con cruz) ---
	for ball: Node in balls:
		if ball is RigidBody2D:
			var pos: Vector2 = panel.world_to_minimap(ball.global_position)
			var color: Color = Color.WHITE
			if ball.get("ball_color") != null:
				color = ball.ball_color
			_draw_ball_icon(pos, 6.0, color)
	
	# --- Jugador local (chevron, siempre centrado, encima de todo) ---
	var local_pos: Vector2 = map_size / 2.0
	var local_color: Color = Color.WHITE
	if local_player.get("player_color") != null:
		local_color = local_player.player_color
	var direction: Vector2 = local_player.velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	_draw_player_chevron(local_pos, 10.0, local_color, direction)
	
	# --- Leyenda ---
	_draw_legend(map_size, local_color)


# ============================================================
# DIBUJO DE ICONOS
# ============================================================

func _draw_player_chevron(pos: Vector2, s: float, color: Color, direction: Vector2) -> void:
	## Jugador local: flecha/chevron que rota con la dirección de movimiento
	var angle: float = direction.angle() + PI / 2.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s),
		Vector2(-s * 0.7, s * 0.6),
		Vector2(0, s * 0.2),
		Vector2(s * 0.7, s * 0.6),
	])
	var transformed: PackedVector2Array = PackedVector2Array()
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		transformed.append(p.rotated(angle) + pos)
		shadow_pts.append(p.rotated(angle) + pos + Vector2(1.5, 1.5))
	# Sombra
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.5))
	# Relleno
	draw_colored_polygon(transformed, color)
	# Borde blanco
	var border: PackedVector2Array = transformed
	border.append(transformed[0])
	draw_polyline(border, Color.WHITE, 1.5, true)
	# Anillo pulsante
	var pulse: float = (sin(Time.get_ticks_msec() / 400.0) + 1.0) / 2.0
	var ring_c: Color = color
	ring_c.a = 0.2 + pulse * 0.25
	draw_arc(pos, s + 4.0 + pulse * 3.0, 0, TAU, 20, ring_c, 1.5)

func _draw_diamond(pos: Vector2, s: float, color: Color) -> void:
	## Jugador rival: rombo/diamante
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0),
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
	# Borde claro
	var border: PackedVector2Array = transformed
	border.append(transformed[0])
	var border_c: Color = color.lightened(0.3)
	border_c.a = 0.9
	draw_polyline(border, border_c, 1.5, true)

func _draw_ball_icon(pos: Vector2, s: float, color: Color) -> void:
	## Pelota: círculo con cruz interior (estilo pelota de golf)
	# Sombra
	draw_circle(pos + Vector2(1, 1), s + 1.0, Color(0, 0, 0, 0.4))
	# Anillo exterior blanco
	draw_circle(pos, s + 1.0, Color.WHITE)
	# Relleno color
	draw_circle(pos, s, color)
	# Cruz interior
	var cross_c: Color = Color(1, 1, 1, 0.5)
	var cs: float = s * 0.6
	draw_line(pos + Vector2(-cs, 0), pos + Vector2(cs, 0), cross_c, 1.0)
	draw_line(pos + Vector2(0, -cs), pos + Vector2(0, cs), cross_c, 1.0)

func _draw_legend(map_size: Vector2, local_color: Color) -> void:
	## Leyenda pequeña en la parte inferior del minimapa
	var font: Font = ThemeDB.fallback_font
	var fs: int = 9
	var alpha: float = 0.7
	var y: float = map_size.y - 12
	
	# Fondo semitransparente para la leyenda
	var legend_bg: Rect2 = Rect2(Vector2(0, y - 8), Vector2(map_size.x, 20))
	draw_rect(legend_bg, Color(0, 0, 0, 0.45), true)
	
	# "Tú" con punto
	draw_circle(Vector2(8, y), 3, local_color)
	draw_string(font, Vector2(14, y + 3), "Tú", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	
	# "Rival" con diamante mini
	var rx: float = 46
	var dm: PackedVector2Array = PackedVector2Array([
		Vector2(rx, y - 3), Vector2(rx + 3, y), Vector2(rx, y + 3), Vector2(rx - 3, y),
	])
	draw_colored_polygon(dm, Color.GRAY)
	draw_string(font, Vector2(rx + 6, y + 3), "Rival", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
	
	# "Bola" con círculo+cruz
	var bx: float = 96
	draw_circle(Vector2(bx, y), 3, Color.WHITE)
	draw_line(Vector2(bx - 1.5, y), Vector2(bx + 1.5, y), Color(1, 1, 1, 0.5), 1.0)
	draw_line(Vector2(bx, y - 1.5), Vector2(bx, y + 1.5), Color(1, 1, 1, 0.5), 1.0)
	draw_string(font, Vector2(bx + 6, y + 3), "Bola", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))


# ============================================================
# UTILIDADES
# ============================================================

func _find_players_container() -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	return root.find_child("Players", true, false)
