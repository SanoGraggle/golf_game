extends Node2D

## Barra de carga de tiro que aparece encima del jugador.
## Se llena de arriba hacia abajo mientras se mantiene presionado el botón de tiro.
## Muestra visualmente la fuerza con la que se le va a pegar a la pelota.

# Referencia al jugador dueño
var player: CharacterBody2D = null

# Configuración visual
const BAR_WIDTH: float = 6.0           ## Ancho de la barra
const BAR_HEIGHT: float = 32.0         ## Alto total de la barra
const BAR_OFFSET_Y: float = -28.0      ## Offset vertical (encima del jugador)
const BAR_BORDER_WIDTH: float = 1.5    ## Grosor del borde
const MAX_CHARGE_TIME: float = 1.25    ## Debe coincidir con ball.gd

# Colores de la barra (gradiente de verde a rojo)
const COLOR_LOW: Color = Color(0.2, 0.8, 0.3, 0.9)    ## Verde - poca fuerza
const COLOR_MID: Color = Color(1.0, 0.85, 0.1, 0.9)    ## Amarillo - media
const COLOR_HIGH: Color = Color(1.0, 0.2, 0.15, 0.9)   ## Rojo - máxima fuerza
const COLOR_BG: Color = Color(0.1, 0.1, 0.15, 0.7)     ## Fondo de la barra
const COLOR_BORDER: Color = Color(1.0, 1.0, 1.0, 0.8)  ## Borde

# Estado
var is_charging: bool = false
var charge_start_time: float = 0.0
var charge_ratio: float = 0.0    ## 0.0 a 1.0

func _ready() -> void:
	# No se ve hasta que empiece la carga
	visible = false

func start_charge() -> void:
	is_charging = true
	charge_start_time = Time.get_ticks_msec() / 1000.0
	charge_ratio = 0.0
	visible = true

func stop_charge() -> void:
	is_charging = false
	visible = false
	charge_ratio = 0.0

func get_charge_ratio() -> float:
	return charge_ratio

func _process(_delta: float) -> void:
	if not is_charging:
		return
	
	# Calcular cuánto tiempo ha pasado
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = current_time - charge_start_time
	charge_ratio = clampf(elapsed / MAX_CHARGE_TIME, 0.0, 1.0)
	
	queue_redraw()

func _draw() -> void:
	if not is_charging:
		return
	
	var bar_pos: Vector2 = Vector2(-BAR_WIDTH / 2.0, BAR_OFFSET_Y - BAR_HEIGHT)
	var bar_size: Vector2 = Vector2(BAR_WIDTH, BAR_HEIGHT)
	
	# --- Fondo ---
	var bg_rect: Rect2 = Rect2(bar_pos, bar_size)
	draw_rect(bg_rect, COLOR_BG, true)
	
	# --- Barra de carga (se llena de ABAJO hacia ARRIBA) ---
	var fill_height: float = BAR_HEIGHT * charge_ratio
	var fill_rect: Rect2 = Rect2(
		Vector2(bar_pos.x, bar_pos.y + BAR_HEIGHT - fill_height),
		Vector2(BAR_WIDTH, fill_height)
	)
	
	# Color interpolado según el ratio (verde → amarillo → rojo)
	var fill_color: Color
	if charge_ratio < 0.5:
		fill_color = COLOR_LOW.lerp(COLOR_MID, charge_ratio * 2.0)
	else:
		fill_color = COLOR_MID.lerp(COLOR_HIGH, (charge_ratio - 0.5) * 2.0)
	
	draw_rect(fill_rect, fill_color, true)
	
	# --- Líneas de marcas de fuerza (25%, 50%, 75%) ---
	var mark_color: Color = Color(1, 1, 1, 0.3)
	for i: int in range(1, 4):
		var mark_y: float = bar_pos.y + BAR_HEIGHT * (1.0 - float(i) / 4.0)
		draw_line(
			Vector2(bar_pos.x, mark_y),
			Vector2(bar_pos.x + BAR_WIDTH, mark_y),
			mark_color, 1.0
		)
	
	# --- Borde ---
	draw_rect(bg_rect, COLOR_BORDER, false, BAR_BORDER_WIDTH)
	
	# --- Indicador de nivel actual (línea horizontal brillante) ---
	if charge_ratio > 0.01:
		var indicator_y: float = bar_pos.y + BAR_HEIGHT - fill_height
		var glow_color: Color = Color.WHITE
		glow_color.a = 0.9
		draw_line(
			Vector2(bar_pos.x - 2, indicator_y),
			Vector2(bar_pos.x + BAR_WIDTH + 2, indicator_y),
			glow_color, 2.0
		)

