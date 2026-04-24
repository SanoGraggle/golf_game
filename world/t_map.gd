extends Node2D

@onready var players: Node2D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_spawner.spawn_path = NodePath("Players")
	player_spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		_spawn_existing_players()


func _spawn_player(peer_id: int) -> Node:
	var player_scene: PackedScene = preload("res://player/player.tscn")
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.set_multiplayer_authority(1)
	player.global_position = _get_spawn_positio(peer_id)
	return player

func _spawn_existing_players() -> void:
	for player: Statics.PlayerData in Game.players:
		player_spawner.spawn(player.id)

func _get_spawn_position(peer_id: int) -> Vector2:
	var player_data: Statics.PlayerData = Game.get_player(peer_id)
	var index: int = player_data.index if player_data else 0
	return Vector2(200 + index*96, 200)
