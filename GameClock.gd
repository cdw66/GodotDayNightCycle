extends Node

signal time_updated(day: int, hour: int, minute: int)

var day: int = 1
var hour: int = 8
var minute: int = 0
var paused: bool = false

@export var seconds_per_in_game_minute: float = 1.25
#@export var seconds_per_in_game_minute: float = 0.1

var _accumulator := 0.0

func _process(delta: float) -> void:
	if paused:
		#$ClockLabel.hidden = true
		return

	_accumulator += delta
	if _accumulator >= seconds_per_in_game_minute:
		_accumulator -= seconds_per_in_game_minute
		_advance_time()

func _advance_time() -> void:
	minute += 1
	if minute >= 60:
		minute = 0
		hour += 1
		if hour >= 24:
			hour = 0
			day += 1
	print("Time advanced: Day %d - %02d:%02d" % [day, hour, minute])
	emit_signal("time_updated", day, hour, minute)

func set_time(new_day: int, new_hour: int, new_minute: int) -> void:
	day = new_day
	hour = new_hour
	minute = new_minute
	emit_signal("time_updated", day, hour, minute)

func pause():
	paused = true

func resume():
	paused = false
