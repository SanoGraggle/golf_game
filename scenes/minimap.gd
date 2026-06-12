extends Control

## Minimapa que muestra una copia real del mapa usando un SubViewport compartido.
## Renderiza el terreno/tilemap real + iconos descriptivos de jugadores y pelotas encima.

var local_player: CharacterBody2D = null
var local_ball: RigidBody2D = null

# Configuración del minimapa
@export var map_size: Vector2 = Vector2(160, 160)       ## Tamaño del minimapa en píxeles
@export var map_margin: Vector2 = Vector2(16, 16)       ## Margen desde la esquina
@export var world_range: float = 400.0                   ## Radio del mundo visible (más bajo = más zoom)

# Nodos hijos (definidos en la escena)
@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var sub_viewport: SubViewport = $ViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $ViewportContainer/SubViewport/MinimapCamera
@onready var icon_overlay: Control = $IconOverlay

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	_setup_viewport()
	_update_layout()

func _setup_viewport() -> void:
	# Esperamos un frame para que el mundo principal esté listo
	await get_tree().process_frame
	
	# Compartir el world_2d del viewport principal para que el SubViewport
	# renderice el mismo mundo (tilemap, sprites, etc.)
	sub_viewport.world_2d = get_viewport().world_2d
	
	# Calcular zoom: queremos que world_range*2 unidades del mundo
	# quepan en map_size píxeles del minimapa
	var zoom_level: float = map_size.x / (world_range * 2.0)
	minimap_camera.zoom = Vector2(zoom_level, zoom_level)

func setup(player: CharacterBody2D, ball: RigidBody2D) -> void:
	local_player = player
	local_ball = ball

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = Vector2(
		viewport_size.x - map_size.x - map_margin.x,
		viewport_size.y - map_size.y - map_margin.y
	)
	custom_minimum_size = map_size
	size = map_size
	viewport_container.size = map_size
	icon_overlay.position = Vector2.ZERO
	icon_overlay.size = map_size

func _process(_delta: float) -> void:
	if not is_instance_valid(local_player):
		return
	
	# La cámara del minimapa sigue al jugador local
	minimap_camera.position = local_player.global_position
	
	_update_layout()
	icon_overlay.queue_redraw()

## Convierte posición del mundo a coordenadas del minimapa (centrado en el jugador).
func world_to_minimap(world_pos: Vector2) -> Vector2:
	if not is_instance_valid(local_player):
		return map_size / 2.0
	var relative: Vector2 = world_pos - local_player.global_position
	var normalized: Vector2 = relative / world_range
	var minimap_pos: Vector2 = (normalized + Vector2.ONE) * 0.5 * map_size
	minimap_pos.x = clampf(minimap_pos.x, 2, map_size.x - 2)
	minimap_pos.y = clampf(minimap_pos.y, 2, map_size.y - 2)
	return minimap_pos
