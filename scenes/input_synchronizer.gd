class_name InputSynchronizer
extends MultiplayerSynchronizer

@export var move_input: Vector2

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	move_input = Input.get_vector("move_left","move_right","move_up","move_down")
