extends Node

signal time_updated(day: int, hour: int, minute: int)

var day: int = 1
var hour: int = 5
var minute: int = 0
var paused: bool = false

@export var seconds_per_in_game_minute: float = 1.25
#@export var seconds_per_in_game_minute: float = 0.01

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

# Function for getting the precise hour as a float
func get_current_precise_hour() -> float:
	# Calculate the fraction of the current in-game minute that has passed
	# based on the time accumulated since the last minute tick.
	var minute_progress: float = 0.0
	# Prevent division by zero if time speed is extremely fast or zero
	if seconds_per_in_game_minute > 0.0001:
		minute_progress = _accumulator / seconds_per_in_game_minute

	# Clamp progress just in case accumulator slightly exceeds due to float precision
	minute_progress = clamp(minute_progress, 0.0, 1.0)

	# Calculate the total precise minute and hour
	var precise_minute: float = float(minute) + minute_progress
	var precise_hour: float = float(hour) + (precise_minute / 60.0)

	# Return the value, ensuring it wraps around 24 hours correctly using fposmod
	# fposmod ensures the result is always positive, unlike regular fmod
	return fposmod(precise_hour, 24.0)
