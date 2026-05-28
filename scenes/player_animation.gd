extends Node2D

@export var animation_tree: AnimationTree
@export var sprite: Sprite2D

@onready var player := get_parent() as CharacterBody2D
@onready var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
var last_direction := Vector2(0, 1) # Default idle_down


func _ready() -> void:
	animation_tree.active = true


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var velocity := player.velocity

	if velocity.length() > 0.1:
		var direction := velocity.normalized()

		# Store the last facing direction.
		if abs(direction.x) > abs(direction.y):
			last_direction = Vector2(1, 0)

			# Mirror right animation when moving left.
			sprite.flip_h = direction.x < 0.0
		else:
			sprite.flip_h = false

			if direction.y < 0.0:
				last_direction = Vector2(0, -1)
			else:
				last_direction = Vector2(0, 1)

		animation_tree.set("parameters/Walk/blend_position", last_direction)
		state_machine.travel("Walk")

	else:
		animation_tree.set("parameters/Idle/blend_position", last_direction)
		state_machine.travel("Idle")
