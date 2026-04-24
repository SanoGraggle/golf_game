extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
	# Add the gravity.

	# Handle jump.
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	#send_position.rpc(global_position)
	
func setup(data: Statics.PlayerData) -> void:
	name = str(data.id)
	set_multiplayer_authority(data.id, false)
	multiplayer_synchronizer.set_multiplayer_authority(data.id, false)

@rpc("authority", "call_remote", "unreliable_ordered")
func send_position(pos: Vector2) -> void:
	global_position = pos
