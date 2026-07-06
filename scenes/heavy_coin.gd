extends Area2D

## Moneda morada — Pelota Pesada
## Al recogerla, hace la pelota del RIVAL más pesada (más lenta, menos rebote).

signal coin_collected(peer_id: int)

const HEAVY_DURATION := 6.0
const HEAVY_DAMP_MULTIPLIER := 4.0      ## Cuánto más damping (pelota se frena más rápido)
const HEAVY_BOUNCE_REDUCTION := 0.15    ## Bounce muy bajo cuando está pesada

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
		_apply_heavy_effect(collector_id)
		collect_coin.rpc()
	else:
		request_collect.rpc_id(1, collector_id)

func _apply_heavy_effect(collector_id: int) -> void:
	coin_collected.emit(collector_id)

	for ball in get_tree().get_nodes_in_group("balls"):
		var ball_owner_id: int = 0
		if ball.has_method("get_owner_id"):
			ball_owner_id = ball.get_owner_id()
		else:
			ball_owner_id = ball.name.replace("Ball_", "").to_int()
		if ball_owner_id != collector_id and ball.has_method("apply_heavy"):
			ball.apply_heavy(HEAVY_DAMP_MULTIPLIER, HEAVY_BOUNCE_REDUCTION, HEAVY_DURATION)

	var players_node: Node = get_tree().root.find_child("Players", true, false)
	if players_node:
		for player in players_node.get_children():
			if str(player.name) != str(collector_id) and player.has_method("show_heavy_ball_effect"):
				player.show_heavy_ball_effect(HEAVY_DURATION)

@rpc("any_peer", "call_local", "reliable")
func request_collect(collector_id: int) -> void:
	if not multiplayer.is_server():
		return

	_apply_heavy_effect(collector_id)
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
