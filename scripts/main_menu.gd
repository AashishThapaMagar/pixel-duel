extends Control
## The game's entry point (project.godot run/main_scene). Two screens sharing
## one Control: MainScreen (Play/Settings/Exit) and SettingsScreen
## (fullscreen + volume, backed by the Settings autoload), toggled by
## show/hiding rather than swapping scenes since there's so little to it.

@onready var main_screen: Control = $MainScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var fullscreen_check: CheckBox = $SettingsScreen/VBox/FullscreenCheck
@onready var volume_slider: HSlider = $SettingsScreen/VBox/VolumeRow/VolumeSlider

func _ready() -> void:
	_show_main()
	fullscreen_check.button_pressed = Settings.fullscreen
	volume_slider.value = Settings.volume

	$MainScreen/VBox/PlayButton.pressed.connect(_on_play_pressed)
	$MainScreen/VBox/SettingsButton.pressed.connect(_show_settings)
	$MainScreen/VBox/ExitButton.pressed.connect(_on_exit_pressed)
	$SettingsScreen/VBox/BackButton.pressed.connect(_show_main)
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	volume_slider.value_changed.connect(Settings.set_volume)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_main() -> void:
	main_screen.visible = true
	settings_screen.visible = false

func _show_settings() -> void:
	main_screen.visible = false
	settings_screen.visible = true
