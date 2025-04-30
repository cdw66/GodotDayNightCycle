extends Node

signal time_updated(day: int, hour: int, minute: int)

var day: int = 1
var hour: int = 5
var minute: int = 0
var paused: bool = false

@export var seconds_per_in_game_minute: float = 1.25

# --- Time Warp Variables ---
var time_warp_multiplier: float = 1.0 # 1.0 = normal speed, > 1.0 = faster, < 1.0 = slower
const TIME_WARP_MIN: float = 0.125    # Minimum speed multiplier (e.g., 1/8th speed)
const TIME_WARP_MAX: float = 64.0     # Maximum speed multiplier (e.g., 64x speed)
# --------------------------

var _accumulator := 0.0

# --- NEW: Handle Input for Time Warp ---
func _input(event: InputEvent) -> void:
	# Check if the increase action ("/" key by default) is just pressed
	if event.is_action_pressed("increase_time_warp"):
		time_warp_multiplier *= 2.0 # Double the speed
		time_warp_multiplier = clamp(time_warp_multiplier, TIME_WARP_MIN, TIME_WARP_MAX)
		print("GameClock: Time Warp set to ", time_warp_multiplier, "x")
		get_viewport().set_input_as_handled() # Prevents event from propagating further

	# Check if the decrease action ("." key by default) is just pressed
	if event.is_action_pressed("decrease_time_warp"):
		time_warp_multiplier /= 2.0 # Halve the speed
		time_warp_multiplier = clamp(time_warp_multiplier, TIME_WARP_MIN, TIME_WARP_MAX)
		print("GameClock: Time Warp set to ", time_warp_multiplier, "x")
		get_viewport().set_input_as_handled() # Prevents event from propagating further

# --- MODIFIED _process ---
func _process(delta: float) -> void:
	if paused:
		return

	# Apply the time warp multiplier to the delta time
	var effective_delta = delta * time_warp_multiplier
	_accumulator += effective_delta

	# Check if enough accumulated time has passed for one or more minutes
	# Use the base configured speed for the check
	if _accumulator >= seconds_per_in_game_minute:
		# Calculate how many full minutes have passed (can be > 1 if warp is high)
		# Ensure we don't advance time if the configured speed is near zero
		var minutes_passed: int = 0
		if seconds_per_in_game_minute > 0.0001:
			minutes_passed = int(floor(_accumulator / seconds_per_in_game_minute))

		# Subtract the time for the minutes that passed
		_accumulator -= float(minutes_passed) * seconds_per_in_game_minute

		# Advance time for each minute passed
		for i in range(minutes_passed):
			# Re-check pause in case it was paused mid-frame by another script
			if paused:
				break
			_advance_time()

# --- _advance_time remains the same ---
func _advance_time() -> void:
	minute += 1
	if minute >= 60:
		minute = 0
		hour += 1
		if hour >= 24:
			hour = 0
			day += 1
	# Optional: Modify print to show multiplier if you want
	# print("Time advanced (Warp: %sx): Day %d - %02d:%02d" % [time_warp_multiplier, day, hour, minute])
	emit_signal("time_updated", day, hour, minute) # Signal discrete minute changes

# --- set_time remains the same ---
func set_time(new_day: int, new_hour: int, new_minute: int) -> void:
	# Consider resetting accumulator or multiplier when manually setting time? Optional.
	# _accumulator = 0.0
	# time_warp_multiplier = 1.0 # Optional reset on manual set
	day = new_day
	hour = new_hour
	minute = new_minute
	emit_signal("time_updated", day, hour, minute)

# --- pause/resume remain the same ---
func pause():
	paused = true

func resume():
	paused = false

# --- get_current_precise_hour remains the same ---
# It correctly uses the current _accumulator and the base seconds_per_in_game_minute
# to calculate the fractional progress within the *current* minute being timed.
func get_current_precise_hour() -> float:
	var minute_progress: float = 0.0
	if seconds_per_in_game_minute > 0.0001:
		minute_progress = _accumulator / seconds_per_in_game_minute
	minute_progress = clamp(minute_progress, 0.0, 1.0)
	var precise_minute: float = float(minute) + minute_progress
	var precise_hour: float = float(hour) + (precise_minute / 60.0)
	return fposmod(precise_hour, 24.0)
