extends Node2D

@export var player_scene: PackedScene
@onready var players: Node2D = $Players
@onready var spawn_points: Node2D = $SpawnPoints

@onready var balls_container: Node2D = $BallsContainer
@onready var ball_spawner: MultiplayerSpawner = $BallSpawner

var ball_scene = preload("res://scenes/ball.tscn")

const PLAYER_COLORS = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW,
	Color.PURPLE, Color.ORANGE, Color.MAGENTA, Color.CYAN
]

func _ready() -> void:
	ball_spawner.spawn_path = balls_container.get_path()
	ball_spawner.add_spawnable_scene("res://scenes/ball.tscn")
	
	for i in Game.players.size():
		var player_data = Game.players[i]
		var assigned_color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		
		# 1. Instanciar Jugador
		var player_inst = player_scene.instantiate()
		players.add_child(player_inst, true)
		var spawn_point = spawn_points.get_child(i)
		player_inst.global_position = spawn_point.global_position
		player_inst.setup(player_data)
		
		# Asignamos el color al personaje del jugador
		player_inst.player_color = assigned_color
		
		# 2. Instanciar Pelota (Solo en Servidor)
		if multiplayer.is_server():
			spawn_ball_for_player(player_data.id, assigned_color, spawn_point.global_position)

func spawn_ball_for_player(peer_id: int, ball_color: Color, spawn_pos: Vector2) -> void:
	var ball = ball_scene.instantiate()
	ball.name = "Ball_" + str(peer_id)
	ball.position = spawn_pos + Vector2(30, 0)
	ball.ball_color = ball_color
	
	# FIJADO: Línea de player_owner_id eliminada para evitar el crash
	balls_container.add_child(ball, true)
