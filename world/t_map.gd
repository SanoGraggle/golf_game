extends Node2D

@export var player_scene: PackedScene
@onready var players: Node2D = $Players
#@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node2D = $SpawnPoints


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in Game.players.size():
		var player_inst = player_scene.instantiate()
		players.add_child(player_inst, true)
		var spawn_point = spawn_points.get_child(i)
		player_inst.global_position = spawn_point.global_position
#	player_spawner.spawn_path = NodePath("Players")
#	player_spawner.spawn_function = _spawn_player

#	if multiplayer.is_server():
#		_spawn_existing_players()


#func _spawn_player(peer_id: int) -> Node:
#	var player_scene: PackedScene = preload("res://scenes/player.tscn")
#	var player := player_scene.instantiate()
#	player.name = str(peer_id)
#	player.peer_id = peer_id
#	player.set_multiplayer_authority(1)
#	player.global_position = _get_spawn_position(peer_id)
#	return player

#func _spawn_existing_players() -> void:
#	for player: Statics.PlayerData in Game.players:
#		player_spawner.spawn(player.id)

#func _get_spawn_position(peer_id: int) -> Vector2:
#	var player_data: Statics.PlayerData = Game.get_player(peer_id)
#	var index: int = player_data.index if player_data else 0
#	return Vector2(200 + index*96, 200)
