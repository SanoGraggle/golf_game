extends Area2D

## Moneda roja — Super Golpe
## Al recogerla, el siguiente tiro del jugador sale con más fuerza y la pelota rebota más.

signal coin_collected(peer_id: int)

const POWER_SHOT_DURATION := 8.0
const POWER_SHOT_FORCE_MULTIPLIER := 2.0
const POWER_SHOT_BOUNCE_MULTIPLIER := 1.8

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Reproducir la animación automáticamente
	$AnimatedSprite2D.play("spin")

func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("balls"):
		return

	var collector_id: int = 0
	if body.has_method("get_owner_id"):
		collector_id = body.get_owner_id()
	else:
		collector_id = body.name.replace("Ball_", "").to_int()

	if collector_id <= 0:
		return

	if multiplayer.is_server():
		_apply_power_shot(body, collector_id)
		collect_coin.rpc()
	else:
		request_collect.rpc_id(1, collector_id)

func _apply_power_shot(ball_node: Node, collector_id: int) -> void:
	coin_collected.emit(collector_id)

	if ball_node and ball_node.has_method("apply_power_shot"):
		ball_node.apply_power_shot(POWER_SHOT_FORCE_MULTIPLIER, POWER_SHOT_BOUNCE_MULTIPLIER, POWER_SHOT_DURATION)

	var player_node: Node = get_tree().root.find_child(str(collector_id), true, false)
	if player_node and player_node.has_method("show_power_shot_effect"):
		player_node.show_power_shot_effect(POWER_SHOT_DURATION)

@rpc("any_peer", "call_local", "reliable")
func request_collect(collector_id: int) -> void:
	if not multiplayer.is_server():
		return

	var ball_node: Node = null
	for candidate in get_tree().get_nodes_in_group("balls"):
		if candidate.has_method("get_owner_id") and candidate.get_owner_id() == collector_id:
			ball_node = candidate
			break

	if ball_node == null:
		ball_node = get_tree().root.find_child("Ball_" + str(collector_id), true, false)

	_apply_power_shot(ball_node, collector_id)
	collect_coin.rpc()

@rpc("authority", "call_local", "reliable")
func collect_coin() -> void:
	# Desactivar colisiones para no recoger dos veces
	set_deferred("monitoring", false)
	# Animación de recolección: escalar hacia arriba y desvanecer
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.5, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
