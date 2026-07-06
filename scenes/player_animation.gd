extends Node2D

const GOLF_HOLD_TIME: float = 0.1
const GOLF_RELEASE_TIME: float = 0.5

@export var animation_tree: AnimationTree
@export var sprite: Sprite2D

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

var last_direction: Vector2 = Vector2(0, 1)
var golf_blend_direction: Vector2 = Vector2(0, 1)
var was_charging_shot: bool = false
var release_time_left: float = 0.0
var release_playing: bool = false


func _ready() -> void:
	animation_tree.active = true


func _physics_process(delta: float) -> void:
	if player == null:
		return

	if bool(player.get("is_charging_shot")):
		var shoot_direction: Vector2 = get_shoot_direction()
		apply_direction("parameters/GolfHold/GolfBlend/blend_position", shoot_direction)
		state_machine.travel("GolfHold")
		animation_tree.set("parameters/GolfHold/HoldSeek/seek_request", GOLF_HOLD_TIME)
		animation_tree.set("parameters/GolfHold/HoldFreeze/scale", 0.0)
		was_charging_shot = true
		return

	if was_charging_shot:
		was_charging_shot = false
		if bool(player.get("is_shot_cancelled")):
			player.set("is_shot_cancelled", false)
			update_movement_animation()
			return
			
		state_machine.travel("GolfRelease")
		animation_tree.set("parameters/GolfRelease/GolfBlend/blend_position", golf_blend_direction)
		animation_tree.set("parameters/GolfRelease/ReleaseSeek/seek_request", GOLF_HOLD_TIME)
		release_time_left = GOLF_RELEASE_TIME
		release_playing = true
		return

	if release_playing:
		release_time_left -= delta
		if release_time_left > 0.0:
			return
		release_playing = false

	update_movement_animation()


func get_shoot_direction() -> Vector2:
	var origin: Vector2 = player.global_position

	if player.has_method("get_my_ball"):
		var result: Variant = player.call("get_my_ball")
		if result is Node2D:
			origin = (result as Node2D).global_position

	var direction: Vector2 = player.get_global_mouse_position() - origin
	if direction.length() <= 0.001:
		return last_direction

	return direction.normalized()


func apply_direction(blend_path: String, direction: Vector2) -> void:
	var blend_direction: Vector2

	if abs(direction.x) > abs(direction.y):
		blend_direction = Vector2(1, 0)
		sprite.flip_h = direction.x < 0.0
	else:
		sprite.flip_h = false
		blend_direction = Vector2(0, -1) if direction.y < 0.0 else Vector2(0, 1)

	last_direction = blend_direction
	golf_blend_direction = blend_direction
	animation_tree.set(blend_path, blend_direction)


func update_movement_animation() -> void:
	var current_velocity: Vector2 = player.velocity	

	if current_velocity.length() > 0.1:
		apply_direction("parameters/Walk/blend_position", current_velocity.normalized())
		state_machine.travel("Walk")
	else:
		animation_tree.set("parameters/Idle/blend_position", last_direction)
		state_machine.travel("Idle")
