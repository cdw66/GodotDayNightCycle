extends Node3D

@onready var sun_light = $SunLight
@onready var moon_light = $MoonLight

# Settings
@export_range(0, 23) var day_start_hour: int = 6 # Hour when the sun is at the horizon (rising)
@export_range(0, 23) var night_start_hour: int = 20 # Hour when the sun is at the horizon (setting) / moon rises

@export var max_day_light_energy: float = 1.0
@export var max_night_light_energy: float = 0.2

@export var day_light_color: Color = Color(1, 1, 0.9)
@export var night_light_color: Color = Color(0.6, 0.7, 1.0)

# Define the rotation angles for key positions
const SUNRISE_ANGLE: float = 0.0   # Sun at horizon
const NOON_ANGLE: float = -90.0  # Sun at peak
const SUNSET_ANGLE: float = -180.0 # Sun at opposite horizon

const MOONRISE_ANGLE: float = 0.0  # Moon at horizon
const MOON_PEAK_ANGLE: float = -90.0 # Moon at peak
const MOONSET_ANGLE: float = -180.0# Moon at opposite horizon

# Default day/night duration values
var _day_duration_hours: float = 12.0
var _night_duration_hours: float = 12.0

func _ready():
	# Calculate initial day/night durations
	_calculate_durations()
	# Connect to the GameClock singleton's signal
	if GameClock != null:
		GameClock.time_updated.connect(_on_time_updated)
		_on_time_updated(GameClock.day, GameClock.hour, GameClock.minute)
	else:
		push_warning("DayNightCycle: GameClock singleton not found.")
		_update_cycle(8.0) # Default to 8 AM

# Called whenever GameClock emits 'time_updated' signal
func _on_time_updated(day: int, hour: int, minute: int) -> void:
	_calculate_durations() # Recalculate in case values changed in editor
	var current_hour_float: float = hour + (minute / 60.0)
	# Call main update function
	_update_cycle(current_hour_float)

# Helper to calculate hours since a start hour, handling wrap-around
func _get_hours_since(start_hour: float, current_hour: float) -> float:
	if current_hour >= start_hour:
		return current_hour - start_hour
	else:
		return (24.0 - start_hour) + current_hour

# Helper to determine if it's currently daytime based on start/end times
func _is_daytime(current_hour: float) -> bool:
	var start = float(day_start_hour)
	var end = float(night_start_hour)

	if start < end: # Normal case (e.g., 6 to 18)
		return current_hour >= start and current_hour < end
	else: # Day wraps around midnight (e.g., 20 to 5)
		return current_hour >= start or current_hour < end

# Calculates total length of day and night periods in hours
func _calculate_durations() -> void:
	var start = float(day_start_hour)
	var end = float(night_start_hour)

	# Calculate day duration (handles wrap-around)
	if end >= start:
		_day_duration_hours = end - start
	else:
		_day_duration_hours = (24.0 - start) + end

	# Night duration is remaining time in a 24-hour cycle
	_night_duration_hours = 24.0 - _day_duration_hours

	# Prevent division by zero / invalid states
	if _day_duration_hours <= 0.001: _day_duration_hours = 12.0
	if _night_duration_hours <= 0.001: _night_duration_hours = 12.0

# Core day/night cycle update function
func _update_cycle(current_hour_float: float) -> void:
	# --- Determine Progress ---
	# Calculate progress through the day period
	var time_since_day_start: float = _get_hours_since(day_start_hour, current_hour_float)
	var day_progress: float = clamp(time_since_day_start / _day_duration_hours, 0.0, 1.0)

	# Calculate progress through the night period
	var time_since_night_start: float = _get_hours_since(night_start_hour, current_hour_float)
	var night_progress: float = clamp(time_since_night_start / _night_duration_hours, 0.0, 1.0)

	# --- Rotation (Based on Day/Night Progress) ---
	var sun_angle_x: float
	var moon_angle_x: float

	# Check if current time is day or night and calcualate sun/moon positions
	if _is_daytime(current_hour_float):
		# Daytime: Sun moves across its visible arc, Moon is opposite below horizon
		sun_angle_x = lerp(SUNRISE_ANGLE, SUNSET_ANGLE, day_progress)
		# Moon is opposite the sun's position during the day
		moon_angle_x = sun_angle_x - 180.0
	else:
		# Nighttime: Moon moves across its visible arc, Sun is opposite below horizon
		moon_angle_x = lerp(MOONRISE_ANGLE, MOONSET_ANGLE, night_progress)
		# Sun is opposite the moon's position during the night
		sun_angle_x = moon_angle_x - 180.0

	# Apply rotations (only affecting X-axis for up/down movement across the sky)
	# Ensure angles stay within a reasonable range if needed, e.g., using fposmod or manual wrapping
	sun_light.rotation.x = deg_to_rad(sun_angle_x)
	# Optional: Set Y/Z rotation if you want sunrise/sunset in specific directions
	sun_light.rotation.y = deg_to_rad(-90) # Example: Sun rises East, sets West

	moon_light.rotation.x = deg_to_rad(moon_angle_x)
	# Optional: Set Y/Z rotation for moon
	moon_light.rotation.y = deg_to_rad(-90)


	# --- Intensity (Based on Day/Night Progress) ---
	# Use the same sine curve for smooth fade in/out during the active period
	var sun_fade = clamp(sin(day_progress * PI), 0.0, 1.0)
	var moon_fade = clamp(sin(night_progress * PI), 0.0, 1.0)

	# Apply intensity and color
	sun_light.light_energy = sun_fade * max_day_light_energy
	sun_light.light_color = day_light_color

	moon_light.light_energy = moon_fade * max_night_light_energy
	moon_light.light_color = night_light_color

	# --- Environment (Optional) ---
	# You might want to adjust ambient light, sky, fog etc., based on sun_fade or moon_fade
	#var environment = get_viewport().world_3d.environment
	#if environment:
		#environment.ambient_light_energy = lerp(max_night_light_energy * 0.1, max_day_light_energy * 0.2, sun_fade)
