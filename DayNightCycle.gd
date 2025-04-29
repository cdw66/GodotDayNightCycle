extends Node3D

@onready var sun_light = $SunLight
@onready var moon_light = $MoonLight

# Settings
@export var day_start_hour: int = 6
@export var night_start_hour: int = 18

@export var max_day_light_energy: float = 1.0
@export var max_night_light_energy: float = 0.2

@export var day_light_color: Color = Color(1, 1, 0.9)
@export var night_light_color: Color = Color(0.6, 0.7, 1.0)

func _ready():
	GameClock.time_updated.connect(_on_time_updated)
	_on_time_updated(GameClock.day, GameClock.hour, GameClock.minute)

func _on_time_updated(day: int, hour: int, minute: int) -> void:
	var normalized_time = (hour + (minute / 60.0)) / 24.0

	# Sun arcs from -90 (noon overhead) across the sky
	var sun_angle = lerp(90.0, -270.0, normalized_time)
	sun_light.rotation_degrees = Vector3(sun_angle, 0, 0)

	# Moon is always opposite the sun
	var moon_angle = fposmod(sun_angle + 180.0, 360.0)
	moon_light.rotation_degrees = Vector3(moon_angle, 0, 0)
	
	# Light intensities based on their angles
	var sun_fade = get_sun_fade()
	var moon_fade = get_moon_fade()

	sun_light.light_energy = sun_fade * max_day_light_energy
	sun_light.light_color = day_light_color

	moon_light.light_energy = moon_fade * max_night_light_energy
	moon_light.light_color = night_light_color

func get_sun_fade() -> float:
	var angle = sun_light.rotation_degrees.x
	angle = fmod(angle + 180.0, 360.0) - 180.0

	# Shift by 90 degrees to align correctly
	var fade = cos(deg_to_rad(angle + 90.0))

	return clamp(fade, 0.0, 1.0)

func get_moon_fade() -> float:
	var angle = moon_light.rotation_degrees.x
	angle = fmod(angle + 180.0, 360.0) - 180.0

	# Shift by 90 degrees
	var fade = cos(deg_to_rad(angle + 90.0))

	return clamp(fade, 0.0, 1.0)
