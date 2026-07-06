extends Area2D

@onready var power_up_sfx: AudioStreamPlayer2D = $SFX_freeze_coin
@onready var coin_pickup_stream: AudioStream = load("res://assets/Sounds/Coin_Pickup.mp3")



## Señal emitida cuando una pelota recoge la moneda de hielo
signal coin_collected(peer_id: int)

const FREEZE_DURATION := 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Reproducir la animación automáticamente
	$AnimatedSprite2D.play("spin")

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if body.is_in_group("balls"):
		var collector_id: int = body.name.replace("Ball_", "").to_int()
		coin_collected.emit(collector_id)

		# Buscar al jugador RIVAL (cualquier jugador que NO sea el que recogió la moneda)
		var players_node: Node = get_tree().root.find_child("Players", true, false)
		if players_node:
			for player in players_node.get_children():
				if str(player.name) != str(collector_id):
					if player.has_method("apply_freeze"):
						player.apply_freeze(FREEZE_DURATION)

		# Notificar a todos los clientes para ocultar la moneda
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
	if power_up_sfx != null and coin_pickup_stream != null:
		power_up_sfx.stream = coin_pickup_stream
		power_up_sfx.play()
