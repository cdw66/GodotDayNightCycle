extends CanvasLayer

@onready var clock_label = $ClockPanel/ClockLabel

func _ready():
	# Connect to GameClock's signal
	GameClock.time_updated.connect(_on_time_updated)
	_on_time_updated(GameClock.day, GameClock.hour, GameClock.minute)

func _on_time_updated(day: int, hour: int, minute: int) -> void:
	# Update the label text when time changes
	clock_label.text = "Day %d - %02d:%02d" % [day, hour, minute]
