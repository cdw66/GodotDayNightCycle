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

# --- NEW Sky Shader Exports ---
@export var sky_material: ShaderMaterial # Drag your Sky's ShaderMaterial here
@export var sun_texture: Texture2D      # Optional: Drag sun texture here
@export var moon_texture: Texture2D     # Optional: Drag moon texture here

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
	_calculate_durations()

	# Set initial textures on shader (if they exist)
	if sky_material != null:
		var use_tex = false
		if sun_texture != null:
			sky_material.set_shader_parameter("sun_texture", sun_texture)
			use_tex = true
		if moon_texture != null:
			sky_material.set_shader_parameter("moon_texture", moon_texture)
			use_tex = true
		sky_material.set_shader_parameter("use_textures", use_tex)

	# Set the initial state correctly based on the precise start time
	if GameClock != null:
		var initial_precise_hour = GameClock.get_current_precise_hour()
		_update_cycle(initial_precise_hour) # Initial visual setup
	else:
		push_warning("DayNightCycle: GameClock singleton not found for initial setup.")
		_update_cycle(8.0) # Default initial time if clock not found
	# ----------------------------------------------

# Called whenever GameClock emits 'time_updated' signal
#func _on_time_updated(day: int, hour: int, minute: int) -> void:
	#_calculate_durations() # Recalculate in case values changed in editor
	#var current_hour_float: float = hour + (minute / 60.0)
	## Call main update function
	#_update_cycle(current_hour_float)

func _process(delta: float) -> void:
	# Check if GameClock is available and not paused
	if GameClock == null or GameClock.paused:
		# Do nothing if time isn't running
		# You might want to disable lights or visuals here if needed
		return

	# Get the continuously updated precise hour from GameClock
	var precise_hour: float = GameClock.get_current_precise_hour()

	# --- Update the cycle visuals every frame using precise time ---
	# Recalculate durations - can be optimized if start/end hours don't change at runtime
	_calculate_durations()
	# Call the existing update logic function
	_update_cycle(precise_hour)

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
func _update_cycle(precise_hour_float: float) -> void:
	# Determine Progress (uses the smooth precise_hour_float)
	var time_since_day_start: float = _get_hours_since(day_start_hour, precise_hour_float)
	var day_progress: float = clamp(time_since_day_start / _day_duration_hours, 0.0, 1.0) # Clamp to 0-1

	var time_since_night_start: float = _get_hours_since(night_start_hour, precise_hour_float)
	var night_progress: float = clamp(time_since_night_start / _night_duration_hours, 0.0, 1.0) # Clamp to 0-1

	# Rotation (uses the smooth precise_hour_float to determine progress)
	var sun_angle_x: float
	var moon_angle_x: float
	var current_is_daytime = _is_daytime(precise_hour_float) # Check based on precise time

	if current_is_daytime:
		# Clamp progress strictly for shader/fade logic if needed near edges
		day_progress = clamp(day_progress, 0.001, 0.999)
		night_progress = 0.0 # Ensure night progress is 0 during day
		sun_angle_x = lerp(SUNRISE_ANGLE, SUNSET_ANGLE, day_progress)
		moon_angle_x = sun_angle_x - 180.0
	else:
		day_progress = 0.0 # Ensure day progress is 0 during night
		# Clamp progress strictly for shader/fade logic if needed near edges
		night_progress = clamp(night_progress, 0.001, 0.999)
		moon_angle_x = lerp(MOONRISE_ANGLE, MOONSET_ANGLE, night_progress)
		sun_angle_x = moon_angle_x - 180.0

	# Apply Rotations
	sun_light.rotation.x = deg_to_rad(sun_angle_x)
	sun_light.rotation.y = deg_to_rad(-90) # Assuming you still want this fixed Y rotation
	moon_light.rotation.x = deg_to_rad(moon_angle_x)
	moon_light.rotation.y = deg_to_rad(-90) # Assuming you still want this fixed Y rotation

	# Intensity (uses progress derived from smooth time)
	var sun_fade = clamp(sin(day_progress * PI), 0.0, 1.0)
	var moon_fade = clamp(sin(night_progress * PI), 0.0, 1.0)

	sun_light.light_energy = sun_fade * max_day_light_energy
	sun_light.light_color = day_light_color
	moon_light.light_energy = moon_fade * max_night_light_energy
	moon_light.light_color = night_light_color

	# Update Sky Shader Uniforms (uses progress derived from smooth time)
	if sky_material != null:
		var sun_dir: Vector3 = sun_light.global_transform.basis.z.normalized()
		var moon_dir: Vector3 = moon_light.global_transform.basis.z.normalized()

		sky_material.set_shader_parameter("sun_direction", sun_dir)
		sky_material.set_shader_parameter("moon_direction", moon_dir)
		# Pass the potentially clamped 0-1 progress values
		sky_material.set_shader_parameter("sun_progress", day_progress)
		sky_material.set_shader_parameter("moon_progress", night_progress)

	## --- Environment (Optional) ---
	## You might want to adjust ambient light, sky, fog etc., based on sun_fade or moon_fade
	##var environment = get_viewport().world_3d.environment
	##if environment:
		##environment.ambient_light_energy = lerp(max_night_light_energy * 0.1, max_day_light_energy * 0.2, sun_fade)
